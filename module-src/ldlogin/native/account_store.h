#pragma once
#include <algorithm>
#include <cerrno>
#include <cctype>
#include <csignal>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <fcntl.h>
#include <set>
#include <string>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>
#include <vector>

static std::string account_trim(std::string s) {
    size_t a = s.find_first_not_of(" \t\r\n"), b = s.find_last_not_of(" \t\r\n");
    return a == std::string::npos ? "" : s.substr(a, b - a + 1);
}
static bool account_field(const std::string& s, size_t max = 256) {
    if (s.empty() || s.size() > max) return false;
    for (unsigned char c : s) if (c < 32 || c == 127 || c == '|') return false;
    return true;
}
static bool account_uuid(std::string& value) {
    if (value.size() != 36) return false;
    for (size_t i = 0; i < value.size(); ++i) {
        if (i == 8 || i == 13 || i == 18 || i == 23) { if (value[i] != '-') return false; }
        else if (!std::isxdigit(static_cast<unsigned char>(value[i]))) return false;
        value[i] = char(std::tolower(static_cast<unsigned char>(value[i])));
    }
    return value != "00000000-0000-0000-0000-000000000000";
}
static bool account_read(const char* path, std::string& out, size_t maximum = 1048576) {
    out.clear();
    int fd = open(path, O_RDONLY | O_CLOEXEC | O_NOFOLLOW);
    if (fd < 0) return false;
    char b[4096]; bool ok = true;
    for (;;) {
        ssize_t n = read(fd, b, sizeof(b));
        if (n < 0) { if (errno == EINTR) continue; ok = false; break; }
        if (!n) break;
        if (out.size() + size_t(n) > maximum) { ok = false; break; }
        out.append(b, size_t(n));
    }
    close(fd); return ok;
}
static bool account_resolve(const std::string& text, std::string uuid, std::string& name) {
    name.clear();
    if (!account_uuid(uuid)) return false;
    std::set<std::string> ids, names;
    size_t start = text.compare(0, 3, "\xef\xbb\xbf") == 0 ? 3 : 0;
    while (start < text.size()) {
        size_t end = text.find('\n', start); if (end == std::string::npos) end = text.size();
        std::string line = account_trim(text.substr(start, end - start)); start = end + 1;
        if (line.empty() || line[0] == '#' || line[0] == ';' || line.compare(0, 2, "//") == 0) continue;
        size_t bar = line.find('|'); if (bar == std::string::npos) return false;
        std::string id = account_trim(line.substr(0, bar)), ld = account_trim(line.substr(bar + 1));
        if (!account_uuid(id) || !account_field(ld, 128) || !ids.insert(id).second || !names.insert(ld).second) return false;
        if (id == uuid) name = ld;
    }
    return !name.empty();
}
struct AccountRow { std::string user, password, ld; size_t start, end; };
static bool account_rows(const std::string& text, std::vector<AccountRow>& rows) {
    rows.clear(); std::set<std::string> users, names;
    size_t start = text.compare(0, 3, "\xef\xbb\xbf") == 0 ? 3 : 0;
    while (start < text.size()) {
        size_t end = text.find('\n', start); if (end == std::string::npos) end = text.size();
        std::string line = account_trim(text.substr(start, end - start));
        const size_t physical_start = start; start = end < text.size() ? end + 1 : end;
        if (line.empty() || line[0] == '#' || line[0] == ';' || line.compare(0, 2, "//") == 0) continue;
        size_t a = line.find('|'), b = a == std::string::npos ? a : line.find('|', a + 1);
        if (a == std::string::npos) continue;
        if (b != std::string::npos && line.find('|', b + 1) != std::string::npos) continue;
        AccountRow row{account_trim(line.substr(0, a)), account_trim(line.substr(a + 1, b == std::string::npos ? b : b - a - 1)),
            b == std::string::npos ? "" : account_trim(line.substr(b + 1)), physical_start, end};
        if (!account_field(row.user) || !account_field(row.password) || (!row.ld.empty() && !account_field(row.ld, 128))) continue;
        if (!users.insert(row.user).second || (!row.ld.empty() && !names.insert(row.ld).second)) return false;
        rows.push_back(std::move(row));
    }
    return true;
}
static bool account_process(pid_t pid, std::string& ticks) {
    std::string stat;
    if (!account_read(("/proc/" + std::to_string(pid) + "/stat").c_str(), stat, 4096)) return false;
    size_t p = stat.rfind(") "); if (p == std::string::npos) return false;
    p += 2;
    if (stat[p] == 'Z' || stat[p] == 'X' || stat[p] == 'x') return false;
    for (int field = 3; field < 22; ++field) {
        p = stat.find(' ', p); if (p == std::string::npos) return false;
        ++p;
    }
    size_t end = stat.find(' ', p); ticks = stat.substr(p, end - p);
    return !ticks.empty();
}
static bool account_owner_dead(pid_t pid, const std::string& expected_ticks) {
    std::string actual;
    if (account_process(pid, actual)) return actual != expected_ticks;
    // A failed /proc read alone is NOT proof of death (permission/I/O error).
    return kill(pid, 0) < 0 && errno == ESRCH;
}
// mkdir coordinates all guests. Recovery is only permitted for a proven dead
// owner in THIS VM (or an older boot of THIS VM), never by PID/age in another VM.
class AccountLock {
    std::string dir_, token_;
    bool owned_ = false;
    bool ours() const {
        std::string value;
        return owned_ && account_read((dir_ + "/owner").c_str(), value, 512) && value == token_;
    }
public:
    bool acquire(const std::string& dir, const std::string& uuid, const std::string& boot) {
        dir_ = dir;
        std::string ticks;
        if (!account_process(getpid(), ticks)) return false;
        token_ = uuid + "|" + boot + "|" + std::to_string(getpid()) + "|" + ticks;
        // A local kernel lock serializes stale-owner recovery in the same VM.
        int guard = open("/data/local/tmp/ldlogin-account-recovery.lock", O_CREAT | O_RDWR | O_CLOEXEC | O_NOFOLLOW, 0600);
        if (guard < 0) return false;
        for (int attempt = 0; attempt < 50; ++attempt) {
            if (flock(guard, LOCK_EX | LOCK_NB) != 0) { usleep(100000); continue; }
            if (mkdir(dir_.c_str(), 0700) == 0) {
                const std::string owner = dir_ + "/owner";
                int fd = open(owner.c_str(), O_CREAT | O_EXCL | O_WRONLY | O_CLOEXEC | O_NOFOLLOW, 0600);
                if (fd >= 0) {
                    bool ok = write(fd, token_.data(), token_.size()) == ssize_t(token_.size()) && fsync(fd) == 0;
                    close(fd); owned_ = ok;
                    if (!ok) { unlink(owner.c_str()); rmdir(dir_.c_str()); }
                } else rmdir(dir_.c_str());
                flock(guard, LOCK_UN); close(guard); return owned_;
            }
            if (errno != EEXIST) { flock(guard, LOCK_UN); close(guard); return false; }
            std::string owner;
            if (account_read((dir_ + "/owner").c_str(), owner, 512)) {
                size_t a = owner.find('|'), b = owner.find('|', a == std::string::npos ? a : a + 1);
                size_t c = owner.find('|', b == std::string::npos ? b : b + 1);
                if (a != std::string::npos && b != std::string::npos && c != std::string::npos && owner.substr(0, a) == uuid) {
                    std::string pid_text = owner.substr(b + 1, c - b - 1), old_boot = owner.substr(a + 1, b - a - 1);
                    char* end = nullptr; long pid = std::strtol(pid_text.c_str(), &end, 10);
                    bool valid = !pid_text.empty() && end && !*end && pid > 1 && pid <= 0x7fffffff && account_uuid(old_boot);
                    bool dead = valid && (old_boot != boot || account_owner_dead(pid_t(pid), owner.substr(c + 1)));
                    if (dead) { unlink((dir_ + "/owner").c_str()); rmdir(dir_.c_str()); }
                }
            }
            flock(guard, LOCK_UN); usleep(100000);
        }
        close(guard); return false;
    }
    bool valid() const { return ours(); }
    ~AccountLock() { if (ours()) { unlink((dir_ + "/owner").c_str()); rmdir(dir_.c_str()); } }
};
static int run_account(const char* path, const char* map_path, const char* uuid_path = "/sys/class/dmi/id/product_uuid") {
    std::string uuid, map, name, boot;
    if (!account_read(uuid_path, uuid, 128) || !account_uuid(uuid = account_trim(uuid)) ||
        !account_read(map_path, map) || !account_resolve(map, uuid, name) ||
        !account_read("/proc/sys/kernel/random/boot_id", boot, 128)) {
        std::fprintf(stderr, "ACCOUNT_IDENTITY_UNAVAILABLE\n"); return 5;
    }
    boot = account_trim(boot);
    std::string file(path); size_t slash = file.find_last_of('/');
    if (slash == std::string::npos) return 5;
    AccountLock lock;
    if (!lock.acquire(file.substr(0, slash) + "/.acc_lock", uuid, boot)) {
        std::fprintf(stderr, "ACCOUNT_LOCK_BUSY_OR_UNVERIFIED\n"); return 6;
    }
    std::string text; std::vector<AccountRow> rows;
    if (!account_read(path, text) || !account_rows(text, rows)) { std::fprintf(stderr, "ACCOUNT_INVALID_OR_DUPLICATE\n"); return 7; }
    const AccountRow* selected = nullptr;
    for (const auto& row : rows) if (row.ld == name) { selected = &row; break; }
    if (!selected) {
        for (const auto& row : rows) if (row.ld.empty()) { selected = &row; break; }
        if (!selected) { std::fprintf(stderr, "ACCOUNT_NOT_ASSIGNED_AND_NONE_FREE\n"); return 7; }
        std::string replacement = selected->user + "|" + selected->password + "|" + name;
        if (selected->end > selected->start && text[selected->end - 1] == '\r') replacement += '\r';
        std::string updated = text; updated.replace(selected->start, selected->end - selected->start, replacement);
        std::string temp = file.substr(0, slash) + "/.acc-write.XXXXXX";
        std::vector<char> tmp(temp.begin(), temp.end()); tmp.push_back(0);
        int fd = mkstemp(tmp.data());
        if (fd < 0) return 8;
        size_t written = 0; bool ok = true;
        while (written < updated.size()) {
            ssize_t n = write(fd, updated.data() + written, updated.size() - written);
            if (n < 0 && errno == EINTR) continue;
            if (n <= 0) { ok = false; break; } written += size_t(n);
        }
        if (fsync(fd) != 0) ok = false;
        close(fd);
        // Never replace a user-edited file or commit under a lost lock.
        std::string before;
        if (!lock.valid() || !account_read(path, before) || before != text) ok = false;
        if (ok && rename(tmp.data(), path) != 0) ok = false;
        unlink(tmp.data());
        std::string verify;
        if (!ok || !account_read(path, verify) || verify != updated) { std::fprintf(stderr, "ACCOUNT_WRITE_FAILED_OR_CHANGED\n"); return 8; }
    }
    if (!lock.valid()) return 6;
    std::printf("ACCOUNT|%s|%s|%s\n", name.c_str(), selected->user.c_str(), selected->password.c_str());
    return 0;
}
