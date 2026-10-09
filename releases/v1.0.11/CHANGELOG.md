# LDMask 1.0.11

- Verify game PID and attached foreground Activity instead of just accepting an am command.
- Keep an already-running game intact; recover absent/stuck startup with force-stop and at most three start attempts.
- Unknown state is not force-stopped. Per-command/overall timeouts and a process-wide launch guard prevent overlapping workers.
- Game launch success/failure is silent. No settings changes or new background monitor.
- LDLogin/LDMenu ZIPs unchanged.
