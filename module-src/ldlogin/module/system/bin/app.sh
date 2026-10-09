#!/system/bin/sh
# =================================================================
# LDLogin
# =================================================================

CONFIG_DIR="/sdcard/ldlogin"
LOG_FILE="$CONFIG_DIR/log.log"
IMAGES_DIR="$CONFIG_DIR/images"

IMG_BALO="$IMAGES_DIR/nut_balo.png"
IMG_VOT="$IMAGES_DIR/chua_cam_vot.png"

# Nguong nhan dien rieng biet cho tung template anh
TH_BALO="0.94"
TH_VOT="0.90"

SCRIPT_BIN_DIR=${0%/*}
FINDER_V2="/system/bin/ldlogin_finder"
if [ -x "$SCRIPT_BIN_DIR/ldlogin_finder" ]; then
    FINDER_V2="$SCRIPT_BIN_DIR/ldlogin_finder"
fi
if [ ! -x "$FINDER_V2" ]; then
    if [ -f "$SCRIPT_BIN_DIR/ldlogin_finder" ]; then
        cp -f "$SCRIPT_BIN_DIR/ldlogin_finder" /data/local/tmp/ldlogin_finder 2>/dev/null
        chmod 755 /data/local/tmp/ldlogin_finder 2>/dev/null
    fi
    FINDER_V2="/data/local/tmp/ldlogin_finder"
fi
mkdir -p "$CONFIG_DIR" 2>/dev/null
mkdir -p "$IMAGES_DIR" 2>/dev/null

ENABLE_LOG=0
LOG_WRITES=0
MAX_LOG_SIZE=524288

# Account identity is resolved from host-generated UUID mapping, never cloneable ld_name.
ACCOUNT_DIR="/mnt/shared/Pictures"
MY_LD_NAME=""

log_msg() {
    [ "$ENABLE_LOG" = "1" ] || return 0
    LOG_WRITES=$((LOG_WRITES + 1))
    if [ "$LOG_WRITES" -ge 50 ]; then
        LOG_WRITES=0
        LOG_SIZE=$(stat -c %s "$LOG_FILE" 2>/dev/null || echo 0)
        if [ "$LOG_SIZE" -ge "$MAX_LOG_SIZE" ]; then
            mv -f "$LOG_FILE" "$LOG_FILE.1" 2>/dev/null
        fi
    fi
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$TIMESTAMP] $1" >> "$LOG_FILE" 2>/dev/null
}

perform_login() {
    bot_may_act || return 0
    reload_runtime_state
    if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
        log_msg "[LOGIN] BOT_RUN_ALLOWED dang tat (BOT_RUN_ALLOWED=$BOT_RUN_ALLOWED). Bo qua dang nhap!"
        return 0
    fi

    # Native transaction: exact physical rows, shared mkdir lock, atomic rename.
    # Missing/duplicate identity must not fall back to LD-1 or a cloned name.
    local account_result account_tag extra account_status TK MK
    account_result=$("$FINDER_V2" --account "$ACCOUNT_DIR/Acc.csv" "$ACCOUNT_DIR/LD-map.txt" 2>/dev/null)
    account_status=$?
    if [ "$account_status" != 0 ]; then
        log_msg "[ERROR] Khong lay duoc tai khoan (code=$account_status): kiem tra Acc.csv, LD-map.txt va khoa tai khoan."
        return 1
    fi
    IFS='|' read -r account_tag MY_LD_NAME TK MK extra <<EOF
$account_result
EOF
    account_result=""
    [ "$account_tag" = ACCOUNT ] && [ -n "$MY_LD_NAME" ] && [ -n "$TK" ] && [ -n "$MK" ] && [ -z "$extra" ] || return 1
    log_msg "[LOGIN] Bat dau dang nhap cho $MY_LD_NAME (khong ghi tai khoan/mat khau vao log)."

    # 1. Nhap tai khoan (txtAccount - toa do 480 212 tren 960x540)
    bot_may_act || return 1
    input tap 480 212
    sleep 0.3
    bot_may_act || return 1
    input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67
    bot_may_act || return 1
    input text "$TK"
    sleep 0.3

    # 2. Nhap mat khau (txtPassword - toa do 480 260 tren 960x540)
    bot_may_act || return 1
    input tap 480 260
    sleep 0.3
    bot_may_act || return 1
    input keyevent 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67 67
    bot_may_act || return 1
    input text "$MK"
    sleep 0.5

    # 3. An nut Dang nhap (btnLogin - toa do 480 316 tren 960x540)
    bot_may_act || return 1
    input tap 480 316
    log_msg "[SUCCESS] Da gui thong tin dang nhap cho $MY_LD_NAME."
    sleep_with_gate 2 || return 1
    return 0
}

start_target_app() {
    bot_may_act || return 1
    PKG="$1"
    log_msg "[START] Dang mo lai app $PKG ..."

    LAUNCH_ACT=$(cmd package resolve-activity --brief "$PKG" 2>/dev/null | tail -n 1)
    if [ -n "$LAUNCH_ACT" ] && [ "$LAUNCH_ACT" != "No activity found" ] && [ "$LAUNCH_ACT" != "$PKG" ]; then
        bot_may_act || return 1
        am start -n "$LAUNCH_ACT" > /dev/null 2>&1
    fi

    bot_may_act || return 1
    monkey -p "$PKG" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1
    bot_may_act || return 1
    monkey -p "$PKG" 1 > /dev/null 2>&1
}

# Ham cho va giam sat crash (tra ve 0 neu thanh cong, 1 neu bi crash)
wait_and_watch_crash() {
    DURATION="$1"
    ELAPSED=0

    while [ "$ELAPSED" -lt "$DURATION" ]; do
        reload_runtime_state
        if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
            return 1
        fi
        PID_NOW=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
        if [ -z "$PID_NOW" ]; then
            log_msg "[ALERT] Game bi crash luc dang cho o giay thu $ELAPSED/$DURATION! Dang khoi dong lai..."
            bot_may_act || return 1
            am force-stop "$TARGET_PKG" > /dev/null 2>&1
            sleep_with_gate 1 || return 1
            start_target_app "$TARGET_PKG"
            return 1
        fi
        sleep_with_gate 5 || return 1
        ELAPSED=$((ELAPSED + 5))
    done
    return 0
}

# Chuoi hanh dong tu dong sau khi mo lai game
handle_post_restart() {
    while true; do
        reload_runtime_state
        if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
            log_msg "[AUTO] BOT_RUN_ALLOWED dang tat -> Dung hanh dong!"
            return 0
        fi

        gate_clock
        START_TIME="$GATE_NOW"

        # 1. Cho 30s dau tien cho game khoi dong va giam sat crash
        log_msg "[AUTO] Cho $WAIT_BEFORE_MENU giay cho game khoi dong (Giam sat crash)..."
        if ! wait_and_watch_crash "$WAIT_BEFORE_MENU"; then
            reload_runtime_state
            if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
                log_msg "[AUTO] BOT_RUN_ALLOWED dang tat -> Dung hanh dong!"
                return 0
            fi
            log_msg "[AUTO] Game bi crash trong 30s dau -> RESET bat dau lai tu dau!"
            continue
        fi

        # 2. Vong lap giam sat dong bo 5s thong minh:
        # - Batch chon nut dat nguong co score cao nhat trong cac ROI.
        # - Balo: cho on dinh, mo panel va lay vot; ZingID: dang nhap.
        # - Xac Nhan / OK / X: xu ly popup.
        # - Canh bao crash lien tuc
        log_msg "[AUTO] Bat dau giam sat dong bo 5s (Nhan dien vao dao, dang nhap & xu ly popup)..."

        while true; do
            reload_runtime_state
            if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
                log_msg "[AUTO] BOT_RUN_ALLOWED dang tat -> Dung hanh dong!"
                return 0
            fi

            gate_clock
            NOW="$GATE_NOW"
            ELAPSED=$((NOW - START_TIME))

            # Gioi han ap dung cho moi trang thai, ke ca khi thay Balo nhung khong thay vot.
            if [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ]; then
                log_msg "[TIMEOUT] Sau ${GAME_LOAD_TIME}s van chua xac nhan lay vot. Dung tu dong nhan dien va chuyen sang canh vang."
                return 1
            fi

            # 2.1. Kiem tra crash
            PID_NOW=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
            if [ -z "$PID_NOW" ]; then
                log_msg "[ALERT] Game bi crash o giay thu ${ELAPSED}s! Dang khoi dong lai..."
                bot_may_act || return 0
                am force-stop "$TARGET_PKG" > /dev/null 2>&1
                sleep_with_gate 1 || return 0
                start_target_app "$TARGET_PKG"
                continue 2
            fi

            # Mot screencap RAM quet toan bo chuoi nut theo thu tu uu tien.
            if [ -x "$FINDER_V2" ]; then
                RES_BATCH=$("$FINDER_V2" --batch "$IMAGES_DIR" 2>/dev/null)
                bot_may_act || return 0
                if echo "$RES_BATCH" | grep -q '^FOUND '; then
                    B_TAG=$(echo "$RES_BATCH" | awk '{print $2}')
                    B_X=$(echo "$RES_BATCH" | awk '{print $3}')
                    B_Y=$(echo "$RES_BATCH" | awk '{print $4}')
                    case "$B_TAG" in
                        BALO)
                            RAND_WAIT=$(( RANDOM % 11 + 20 ))
                            log_msg "[SUCCESS] $RES_BATCH -> Phat hien da vao dao (Giay thu ${ELAPSED}s)! Cho ${RAND_WAIT}s cho giam lag truoc khi mo Balo..."
                            if ! wait_and_watch_crash "$RAND_WAIT"; then
                                log_msg "[ALERT] Game bi crash trong luc cho giam lag -> Bat dau lai!"
                                continue 2
                            fi
                            log_msg "[AUTO] He thong da on dinh het lag! Tien hanh an Balo de cam vot..."
                            bot_may_act || return 0
                            if ! "$FINDER_V2" "$IMG_BALO" "$TH_BALO" --region 860,240,100,140 --click >/dev/null 2>&1; then
                                log_msg "[WARN] Khong bam duoc Balo; khong tim/bam vot tren man hinh sai."
                                sleep_with_gate "$CHECK_INT" || return 0
                                continue
                            fi
                            sleep_with_gate "$DELAY_AFTER_BALO" || return 0
                            VOT_CHECK=0
                            while [ "$VOT_CHECK" -lt 3 ]; do
                                reload_runtime_state
                                if [ "$BOT_RUN_ALLOWED" != "1" ] || [ "$BOT_ACTIVE" != "1" ]; then
                                    log_msg "[AUTO] BOT_RUN_ALLOWED dang tat -> Dung hanh dong!"
                                    return 0
                                fi
                                gate_clock
                                NOW="$GATE_NOW"
                                ELAPSED=$((NOW - START_TIME))
                                [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ] && return 1
                                RES_VOT=$("$FINDER_V2" "$IMG_VOT" "$TH_VOT" --region 50,120,160,160 2>/dev/null)
                                bot_may_act || return 0
                                if echo "$RES_VOT" | grep -q '^FOUND'; then
                                    set -- $RES_VOT
                                    if input tap "$2" "$3"; then
                                        log_msg "[HOAN TAT] Da bam vot tai toa do vua nhan dien. Chuyen sang che do canh vang..."
                                        break 3
                                    fi
                                fi
                                VOT_CHECK=$((VOT_CHECK + 1))
                                log_msg "[WARN] Chua tim thay vot trong Balo (lan $VOT_CHECK/3)."
                                sleep_with_gate 1 || return 0
                            done
                            log_msg "[WARN] Khong tim thay vot sau 3 lan. Fallback bam tam o vot tai (130,200)."
                            bot_may_act || return 0
                            input tap 130 200
                            sleep_with_gate 1 || return 0
                            log_msg "[HOAN TAT] Da fallback bam o vot. Chuyen sang che do canh dong ho..."
                            return 0
                            ;;
                        LOGIN)
                            input tap "$B_X" "$B_Y"
                            log_msg "[SUCCESS] $RES_BATCH -> Da an [Nut Dang Nhap (ZingID)]!"
                            sleep_with_gate 2 || return 0
                            perform_login
                            sleep_with_gate 2 || return 0
                            continue
                            ;;
                        CONFIRM|OK|MENU)
                            input tap "$B_X" "$B_Y"
                            log_msg "[SUCCESS] $RES_BATCH -> Da an [$B_TAG]!"
                            sleep_with_gate 1 || return 0
                            continue
                            ;;
                    esac
                elif echo "$RES_BATCH" | grep -q '^NOT_FOUND'; then
                    if [ "$ELAPSED" -ge "$GAME_LOAD_TIME" ]; then
                        log_msg "[TIMEOUT] Sau ${GAME_LOAD_TIME}s van chua xac nhan lay vot. Dung tu dong nhan dien va chuyen sang canh vang."
                        return 1
                    fi
                    sleep_with_gate "$CHECK_INT" || return 0
                    continue
                fi
                log_msg "[ERROR] ldlogin_finder loi capture/load: $RES_BATCH"
                sleep_with_gate "$CHECK_INT" || return 0
                continue
            else
                log_msg "[ERROR] Khong tim thay ldlogin_finder executable. Dung luong tu dong nhan dien."
                return 1
            fi
        done

        log_msg "[HOAN TAT] Da vao dao va trang bi vot thanh cong! Chuyen sang che do canh vang..."
        break
    done
}

# Thoi gian cho co dinh (Hard-coded)
WAIT_BEFORE_MENU=30
GAME_LOAD_TIME=300
DELAY_AFTER_BALO=2

# Thong so co dinh; khong doc config chung
TARGET_PKG="com.vng.playtogether"
CHECK_INT=5

BOT_RUN_ALLOWED=0
CACHED_PID=""
BOT_ACTIVE=0
GATE_CHECK_SECONDS=5
GATE_IDLE_SECONDS=60

GATE_SCRIPT="$SCRIPT_BIN_DIR/ldlogin_gate.sh"
[ -f "$GATE_SCRIPT" ] || GATE_SCRIPT="/system/bin/ldlogin_gate.sh"
[ -f "$GATE_SCRIPT" ] || exit 1
. "$GATE_SCRIPT"
trap 'gate_stop_watcher' EXIT
trap 'exit 0' HUP INT TERM

log_msg "=== LDLOGIN KHOI DONG ==="

# service.sh da cho Android boot xong va boot_wait_seconds; khong random them.

bot_may_act() {
    reload_runtime_state
    [ "$BOT_RUN_ALLOWED" = "1" ] && [ "$BOT_ACTIVE" = "1" ]
}

# Cho bang FIFO, khong dung sleep de bo lo event tat bot.
# Timeout 5s chi de kiem tra suc khoe watcher, khong polling JSON.
sleep_with_gate() {
    local end stopped="$GATE_OFF_SEQUENCE"
    local step
    gate_clock
    end=$((GATE_NOW + $1))
    while [ "$GATE_NOW" -lt "$end" ]; do
        step="$GATE_CHECK_SECONDS"
        [ $((end - GATE_NOW)) -lt "$step" ] && step=$((end - GATE_NOW))
        wait_bot_gate "$step"
        [ "$stopped" = "$GATE_OFF_SEQUENCE" ] || return 1
        bot_may_act || return 1
        gate_clock
    done
    return 0
}

# LDLogin's native event frame supplies both enabled and logging.
reload_runtime_state() {
    reload_bot_gate
    return 0
}

# Nap cau hinh lan dau tien
reload_runtime_state

LAST_TIMER_PATTERN=""
TIMER_STUCK_COUNT=0
OK_STUCK_COUNT=0
LAST_OK_PRESENT=0
LAST_TIMER_CHECK=0

while true; do
    # 1. Cap nhat setting LDLogin qua FIFO.
    reload_runtime_state

    # Script van song de nhan thao tac bat lai; khong quet anh/click khi tat.
    if [ "$BOT_RUN_ALLOWED" != "1" ]; then
        BOT_ACTIVE=0
        LAST_TIMER_CHECK=0
        TIMER_STUCK_COUNT=0
        OK_STUCK_COUNT=0
        LAST_OK_PRESENT=0
        LAST_TIMER_PATTERN=""
        wait_bot_gate "$GATE_IDLE_SECONDS"
        continue
    fi

    # 2. Kiem tra tien trinh qua PID cache va /proc.
    APP_ALIVE=0
    if [ -n "$CACHED_PID" ] && [ -d "/proc/$CACHED_PID" ]; then
        if grep -q "$TARGET_PKG" "/proc/$CACHED_PID/cmdline" 2>/dev/null; then
            APP_ALIVE=1
        fi
    fi

    if [ "$APP_ALIVE" -eq 0 ]; then
        CACHED_PID=$(pidof "$TARGET_PKG" 2>/dev/null | cut -d ' ' -f1)
        if [ -n "$CACHED_PID" ]; then
            APP_ALIVE=1
        fi
    fi

    # Xu ly ca luc khoi dong va false -> true, ke ca khi game da chay san.
    if [ "$BOT_ACTIVE" -eq 0 ]; then
        BOT_ACTIVE=1
        LAST_TIMER_CHECK=0
        TIMER_STUCK_COUNT=0
        OK_STUCK_COUNT=0
        LAST_OK_PRESENT=0
        LAST_TIMER_PATTERN=""
        if [ "$APP_ALIVE" -eq 0 ]; then
            log_msg "[START] LDLogin enabled. Dang mo game..."
            bot_may_act || continue
            am force-stop "$TARGET_PKG" > /dev/null 2>&1
            sleep_with_gate 1 || continue
            start_target_app "$TARGET_PKG"
            CACHED_PID=""
        else
            log_msg "[START] LDLogin enabled. Game da chay; xu ly vao dao va lay vot..."
        fi
        handle_post_restart
        continue
    fi

    # 3. Neu app bi vang / tat -> Khoi dong lai va chay chuoi xu ly day du
    if [ "$APP_ALIVE" -eq 0 ]; then
        log_msg "[ALERT] App $TARGET_PKG bi vang/tat! Dang khoi dong lai..."
        bot_may_act || continue
        am force-stop "$TARGET_PKG" > /dev/null 2>&1
        sleep_with_gate 1 || continue
        start_target_app "$TARGET_PKG"
        CACHED_PID=""
        LAST_TIMER_CHECK=0
        TIMER_STUCK_COUNT=0
        OK_STUCK_COUNT=0
        LAST_OK_PRESENT=0
        LAST_TIMER_PATTERN=""

        handle_post_restart
        continue
    fi

    # 4. Moi 30s kiem tra dong ho dung yen va nut OK bi ket trong ROI.
    # Hai lan lien tiep (tong 60s theo nhip kiem tra) cua mot trong hai dieu kien se restart game.
    gate_clock
    NOW_TIMER="$GATE_NOW"
    if [ "$LAST_TIMER_CHECK" -eq 0 ] || [ $((NOW_TIMER - LAST_TIMER_CHECK)) -ge 30 ]; then
        LAST_TIMER_CHECK="$NOW_TIMER"
        # One bounded RAM capture supplies both the timer and OK checks.
        RES_HEALTH=$("$FINDER_V2" --health "$IMAGES_DIR" 2>/dev/null)
        bot_may_act || continue
        set -- $RES_HEALTH
        if [ "$1" != HEALTH ]; then
            log_msg "[WARN] Khong lay duoc mau dong ho/OK hop le; xoa bo dem, khong restart nham."
            LAST_TIMER_PATTERN=""
            TIMER_STUCK_COUNT=0
            OK_STUCK_COUNT=0
            LAST_OK_PRESENT=0
            sleep_with_gate "$CHECK_INT"
            continue
        fi
        CUR_PATTERN="$2"
        OK_PRESENT="$3"
        OK_SCORE="$4"

        # Chi kiem tra neu tren man hinh co chu so cua dong ho
        if echo "$CUR_PATTERN" | grep -q "1"; then
            if [ "$CUR_PATTERN" = "$LAST_TIMER_PATTERN" ] && [ -n "$LAST_TIMER_PATTERN" ]; then
                TIMER_STUCK_COUNT=$((TIMER_STUCK_COUNT + 1))
                log_msg "[WARN] Dong ho [Da chay] dung yen lan $TIMER_STUCK_COUNT (da qua $((TIMER_STUCK_COUNT * 30))s)!"

            else
                LAST_TIMER_PATTERN="$CUR_PATTERN"
                TIMER_STUCK_COUNT=0
            fi
        else
            LAST_TIMER_PATTERN=""
            TIMER_STUCK_COUNT=0
        fi

        if [ "$OK_PRESENT" = 1 ]; then
            if [ "$LAST_OK_PRESENT" -eq 1 ]; then
                OK_STUCK_COUNT=$((OK_STUCK_COUNT + 1))
                log_msg "[WARN] Nut OK van xuat hien lan $OK_STUCK_COUNT/2 (da qua $((OK_STUCK_COUNT * 30))s, score: $OK_SCORE)!"
            else
                LAST_OK_PRESENT=1
                OK_STUCK_COUNT=0
            fi
        else
            OK_STUCK_COUNT=0
            LAST_OK_PRESENT=0
        fi

        if [ "$TIMER_STUCK_COUNT" -ge 2 ] || [ "$OK_STUCK_COUNT" -ge 2 ]; then
            if [ "$OK_STUCK_COUNT" -ge 2 ]; then
                RESTART_REASON="Nut OK bi ket lien tuc 60s"
            else
                RESTART_REASON="Game/Auto bi do time suot 60s"
            fi
            log_msg "[ALERT] $RESTART_REASON! Dang khoi dong lai..."
            bot_may_act || continue
            am force-stop "$TARGET_PKG" > /dev/null 2>&1
            sleep_with_gate 1 || continue
            start_target_app "$TARGET_PKG"
            CACHED_PID=""
            LAST_TIMER_CHECK=0
            TIMER_STUCK_COUNT=0
            OK_STUCK_COUNT=0
            LAST_OK_PRESENT=0
            LAST_TIMER_PATTERN=""

            handle_post_restart
            continue
        fi
    fi

    sleep_with_gate "$CHECK_INT"
done
