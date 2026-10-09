.section .rodata.ldmenu_payload,"a",%progbits
.balign 16
.global ldmenu_embedded_start
.hidden ldmenu_embedded_start
ldmenu_embedded_start:
.incbin "D:/App/artifacts/ldmenu-hide-trial-20261009/ldmenu-arm64.so"
.global ldmenu_embedded_end
.hidden ldmenu_embedded_end
ldmenu_embedded_end:
.section .note.GNU-stack,"",%progbits
