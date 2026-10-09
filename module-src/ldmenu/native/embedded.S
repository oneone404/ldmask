.section .rodata.ldmenu_payload,"a",%progbits
.balign 16
.global ldmenu_embedded_start
.hidden ldmenu_embedded_start
ldmenu_embedded_start:
.incbin "module-src/ldmenu/native/original/arm64-v8a.so"
.global ldmenu_embedded_end
.hidden ldmenu_embedded_end
ldmenu_embedded_end:
.section .note.GNU-stack,"",%progbits
