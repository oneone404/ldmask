#pragma once

#include <algorithm>
#include <cstdio>
#include <string>
#include <vector>
#include <cerrno>
#include <fcntl.h>
#include <sys/stat.h>
#include <unistd.h>

struct LDLoginSettings {
    bool enabled = false;
    unsigned boot_wait_seconds = 30;
    bool logging = false;
};

// Validate the whole document. Only LDLogin's root-level typed fields are used.
class ConfigGateJson {
    enum Role { Other, Root, Enabled, BootWait, Logging };
    const std::string& text_;
    size_t pos_ = 0;
    LDLoginSettings settings_;

    void space() {
        while (pos_ < text_.size() && (text_[pos_] == ' ' || text_[pos_] == '\t' ||
               text_[pos_] == '\r' || text_[pos_] == '\n')) ++pos_;
    }
    bool take(char ch) {
        if (pos_ < text_.size() && text_[pos_] == ch) { ++pos_; return true; }
        return false;
    }
    bool literal(const char* word) {
        size_t length = std::char_traits<char>::length(word);
        if (text_.compare(pos_, length, word) != 0) return false;
        pos_ += length;
        return true;
    }
    bool hex4(unsigned& value) {
        value = 0;
        for (int i = 0; i < 4; ++i) {
            if (pos_ >= text_.size()) return false;
            char ch = text_[pos_++];
            unsigned digit;
            if (ch >= '0' && ch <= '9') digit = unsigned(ch - '0');
            else if (ch >= 'a' && ch <= 'f') digit = unsigned(ch - 'a' + 10);
            else if (ch >= 'A' && ch <= 'F') digit = unsigned(ch - 'A' + 10);
            else return false;
            value = value * 16 + digit;
        }
        return true;
    }
    static void utf8(std::string& out, unsigned code) {
        if (code < 0x80) out += char(code);
        else if (code < 0x800) {
            out += char(0xc0 | (code >> 6)); out += char(0x80 | (code & 63));
        } else if (code < 0x10000) {
            out += char(0xe0 | (code >> 12)); out += char(0x80 | ((code >> 6) & 63));
            out += char(0x80 | (code & 63));
        } else {
            out += char(0xf0 | (code >> 18)); out += char(0x80 | ((code >> 12) & 63));
            out += char(0x80 | ((code >> 6) & 63)); out += char(0x80 | (code & 63));
        }
    }
    bool string(std::string& out) {
        if (!take('"')) return false;
        while (pos_ < text_.size()) {
            unsigned char ch = static_cast<unsigned char>(text_[pos_++]);
            if (ch == '"') return true;
            if (ch < 32) return false;
            if (ch >= 0x80) {
                unsigned code, remaining, minimum;
                if (ch >= 0xc2 && ch <= 0xdf) { code = ch & 31; remaining = 1; minimum = 0x80; }
                else if (ch >= 0xe0 && ch <= 0xef) { code = ch & 15; remaining = 2; minimum = 0x800; }
                else if (ch >= 0xf0 && ch <= 0xf4) { code = ch & 7; remaining = 3; minimum = 0x10000; }
                else return false;
                out += char(ch);
                for (unsigned i = 0; i < remaining; ++i) {
                    if (pos_ >= text_.size()) return false;
                    unsigned char next = static_cast<unsigned char>(text_[pos_++]);
                    if ((next & 0xc0) != 0x80) return false;
                    code = (code << 6) | (next & 63);
                    out += char(next);
                }
                if (code < minimum || code > 0x10ffff || (code >= 0xd800 && code <= 0xdfff)) return false;
                continue;
            }
            if (ch != '\\') { out += char(ch); continue; }
            if (pos_ >= text_.size()) return false;
            switch (text_[pos_++]) {
                case '"': out += '"'; break;
                case '\\': out += '\\'; break;
                case '/': out += '/'; break;
                case 'b': out += '\b'; break;
                case 'f': out += '\f'; break;
                case 'n': out += '\n'; break;
                case 'r': out += '\r'; break;
                case 't': out += '\t'; break;
                case 'u': {
                    unsigned code;
                    if (!hex4(code)) return false;
                    if (code >= 0xd800 && code <= 0xdbff) {
                        unsigned low;
                        if (!take('\\') || !take('u') || !hex4(low) || low < 0xdc00 || low > 0xdfff) return false;
                        code = 0x10000 + ((code - 0xd800) << 10) + low - 0xdc00;
                    } else if (code >= 0xdc00 && code <= 0xdfff) return false;
                    utf8(out, code);
                    break;
                }
                default: return false;
            }
        }
        return false;
    }
    bool number() {
        take('-');
        if (!take('0')) {
            if (pos_ >= text_.size() || text_[pos_] < '1' || text_[pos_] > '9') return false;
            do { ++pos_; } while (pos_ < text_.size() && text_[pos_] >= '0' && text_[pos_] <= '9');
        }
        if (take('.')) {
            size_t first = pos_;
            while (pos_ < text_.size() && text_[pos_] >= '0' && text_[pos_] <= '9') ++pos_;
            if (pos_ == first) return false;
        }
        if (take('e') || take('E')) {
            if (!take('+')) take('-');
            size_t first = pos_;
            while (pos_ < text_.size() && text_[pos_] >= '0' && text_[pos_] <= '9') ++pos_;
            if (pos_ == first) return false;
        }
        return true;
    }
    bool value(unsigned depth, Role role) {
        if (depth > 32) return false;
        space();
        if (pos_ >= text_.size()) return false;
        if (role == Enabled || role == Logging) {
            bool value;
            if (literal("true")) value = true;
            else if (literal("false")) value = false;
            else return false;
            if (role == Enabled) settings_.enabled = value;
            else settings_.logging = value;
            return true;
        }
        if (role == BootWait) {
            unsigned seconds = 0;
            size_t first = pos_;
            while (pos_ < text_.size() && text_[pos_] >= '0' && text_[pos_] <= '9') {
                seconds = seconds * 10 + unsigned(text_[pos_++] - '0');
                if (seconds > 600) return false;
            }
            if (pos_ == first || (pos_ - first > 1 && text_[first] == '0')) return false;
            settings_.boot_wait_seconds = seconds;
            return true;
        }
        if (take('{')) {
            std::vector<std::string> keys;
            space();
            if (take('}')) return true;
            do {
                space();
                std::string key;
                if (!string(key) || std::find(keys.begin(), keys.end(), key) != keys.end()) return false;
                keys.push_back(key);
                space();
                if (!take(':')) return false;
                Role child = Other;
                if (role == Root && key == "enabled") child = Enabled;
                if (role == Root && key == "boot_wait_seconds") child = BootWait;
                if (role == Root && key == "logging") child = Logging;
                if (!value(depth + 1, child)) return false;
                space();
                if (take('}')) return true;
            } while (take(','));
            return false;
        }
        if (take('[')) {
            space();
            if (take(']')) return true;
            do {
                if (!value(depth + 1, Other)) return false;
                space();
                if (take(']')) return true;
            } while (take(','));
            return false;
        }
        if (text_[pos_] == '"') { std::string ignored; return string(ignored); }
        if (text_[pos_] == 't') {
            if (!literal("true")) return false;
            return true;
        }
        if (text_[pos_] == 'f') return literal("false");
        if (text_[pos_] == 'n') return literal("null");
        return number();
    }
public:
    explicit ConfigGateJson(const std::string& text) : text_(text) {}
    bool parse(LDLoginSettings& settings) {
        settings = LDLoginSettings{};
        if (text_.size() >= 3 && text_.compare(0, 3, "\xef\xbb\xbf") == 0) pos_ = 3;
        space();
        if (pos_ >= text_.size() || text_[pos_] != '{' || !value(0, Root)) return false;
        space();
        if (pos_ != text_.size()) return false;
        settings = settings_;
        return true;
    }
    bool parse(bool& enabled) {
        LDLoginSettings settings;
        bool valid = parse(settings);
        enabled = valid && settings.enabled;
        return valid;
    }
};

inline bool read_settings_file(const char* path, LDLoginSettings& settings) {
    settings = LDLoginSettings{};
    FILE* stream = std::fopen(path, "rb");
    if (!stream) return false;
    const size_t max_size = 4096;
    std::string content;
    char buffer[4096];
    size_t count;
    while ((count = std::fread(buffer, 1, sizeof(buffer), stream)) != 0) {
        if (content.size() + count > max_size) { std::fclose(stream); return false; }
        content.append(buffer, count);
    }
    bool ok = !std::ferror(stream);
    std::fclose(stream);
    return ok && ConfigGateJson(content).parse(settings);
}

inline bool read_config_gate_file(const char* path, bool& enabled) {
    LDLoginSettings settings;
    bool valid = read_settings_file(path, settings);
    enabled = valid && settings.enabled;
    return valid;
}

// Same-directory temp + fsync + rename. Never publish a half-written enabled flag.
inline bool save_settings_file(const char* path, const LDLoginSettings& settings) {
    if (settings.boot_wait_seconds > 600) return false;
    std::string file(path);
    size_t slash = file.find_last_of('/');
    if (slash == std::string::npos || slash == 0 || slash + 1 == file.size()) return false;
    struct stat existing{};
    if (lstat(path, &existing) == 0) {
        if (!S_ISREG(existing.st_mode)) return false;
    } else if (errno != ENOENT) return false;
    std::string parent = file.substr(0, slash);
    int directory = open(parent.c_str(), O_RDONLY | O_DIRECTORY | O_CLOEXEC | O_NOFOLLOW);
    if (directory < 0) return false;
    std::string temporary = file + ".tmp.XXXXXX";
    std::vector<char> name(temporary.begin(), temporary.end());
    name.push_back(0);
    int fd = mkstemp(name.data());
    if (fd < 0) { close(directory); return false; }
    char json[160];
    int length = std::snprintf(json, sizeof(json),
        "{\"enabled\":%s,\"boot_wait_seconds\":%u,\"logging\":%s}\n",
        settings.enabled ? "true" : "false", settings.boot_wait_seconds,
        settings.logging ? "true" : "false");
    bool ok = fchmod(fd, 0600) == 0;
    int written = 0;
    while (ok && written < length) {
        ssize_t n = write(fd, json + written, size_t(length - written));
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) ok = false;
        else written += int(n);
    }
    if (ok) ok = fsync(fd) == 0;
    if (close(fd) != 0) ok = false;
    if (ok) ok = rename(name.data(), path) == 0;
    if (ok) ok = fsync(directory) == 0;
    close(directory);
    if (!ok) unlink(name.data());
    return ok;
}
