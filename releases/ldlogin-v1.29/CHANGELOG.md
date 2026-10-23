# LDLogin v1.29

- Login-only mode keeps its three decoded image templates in a persistent native matcher.
- Retains the five-second scan wait and fresh screenshot on every scan. LOGIN, CONFIRM and OK handling, thresholds and regions are unchanged.
- Reloads a template when its file identity/size/timestamps change; deleted or corrupt images cannot reuse a stale match.
- Private FIFO requests use shell builtins. Worker is idle between requests, stops when LDLogin is disabled or FramLogin takes over, and is killed on owner exit.
- Worker failure/timeout discards pending results and falls back to the existing one-shot login-only matcher.
- LDMask APK 1.0.19 (27021), LDMenu and LDNPH are unchanged.

Update LDLogin, then reboot LD once to activate the new script. No APK update or re-root is required.
