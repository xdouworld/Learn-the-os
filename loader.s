%include "boot.inc"
SECTION loader vstart=LOADER_BASE_ADDR
LOADER_STACK_TOP equ LOADER_BASE_ADDR 
;jmp loader_start   		  
                      		   

    GDT_BASE        : dd 0x00000000          		   ;刚开始的段选择子0不能使用 故用两个双字 来填充
   		       dd 0x00000000 
    
    CODE_DESC       : dd 0x0000FFFF         		   ;FFFF是与其他的几部分相连接 形成0XFFFFF段界限
    		       dd DESC_CODE_HIGH4
    
    DATA_STACK_DESC : dd 0x0000FFFF
  		       dd DESC_DATA_HIGH4
    		       
    VIDEO_DESC      : dd 0x80000007         		  
                        dd DESC_VIDEO_HIGH4     	   ;0x0007 (bFFFF-b8000)/4k = 0x7
                 
    GDT_SIZE              equ $ - GDT_BASE               ;当前位置减去GDT_BASE的地址 等于GDT的大小
    GDT_LIMIT       	   equ GDT_SIZE - 1   	           ;SIZE - 1即为最大偏移量
    
    times 60 dq 0                             	   ;预留60个 四字型 描述符
    SELECTOR_CODE        equ (0X0001<<3) + TI_GDT + RPL0    
    ;相当于(CODE_DESC - GDT_BASE)/8 + TI_GDT+RPL0
    SELECTOR_DATA	  equ (0X0002<<3) + TI_GDT + RPL0
    SELECTOR_VIDEO       equ (0X0003<<3) + TI_GDT + RPL0
    ;total_mem_bytes用于保存内存容量，以字节为单位
    ;当前偏移loader.bin文件头0x200字节
    ;loader.bin的加载地址是0x900
    ;所以total_mem_bytes的加载地址为0xb00
    total_mem_bytes dd 0
    ;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ;gdt指针 2字gdt界限放在前面 4字gdt地址放在后面 lgdt 48位格式 低位16位界限 高位32位起始地址
    gdt_ptr           dw GDT_LIMIT
    		       dd GDT_BASE
    ards_buf times 244 db 0
    ards_nr dw 0
    
loader_start:
    ;int 15h eax =0000E820h,edx=534D4150h('smap')获取内存布局
    xor ebx,ebx
    mov edx,0x534D4150
    mov di,ards_buf
.e820_mem_get_loop:
    mov edx,0x0000e820
    mov ecx,20
    int 0x15
    jc .e820_failed_so_try_e801
    add di,cx
    inc word [ards_nr]
    cmp ebx,0
    jnz .e820_mem_get_loop
    mov cx,[ards_nr]
    mov ebx,ards_buf
    xor edx,edx
.find_max_mem_area:
    mov eax,[ebx]
    add eax,[ebx+8]
    add ebx,20
    cmp edx,eax
    ;冒泡排序，找出最大edx存储的值
    jge .next_ards
    mov edx,eax
.next_ards:
    loop .find_max_mem_area
    jmp .mem_get_ok

;-----int 15h ax=E801H 获取内存大小，最大支持4g
.e820_failed_so_try_e801:
    mov ax,0xe801
    int 0x15
    jc .e820_failed_so_try_e88
;先算出低15MB的内存
    mov cx,0x400
    mul cx
    shl edx,16
    and eax,0x0000FFFF
    or edx,eax
    add edx,0x100000;ax是1MB,故要加1MB
    mov esi,edx
;在将16MB以上的内容转换为byte为单位
;寄存器bx和dx是以64kb为单位的内存数量
    xor eax,eax
    mov ax,bx
    mov ecx,0x10000
    mul ecx
    add esi,eax
    ;;;
    mov edx,esi
    jmp .mem_get_ok
;-----int 15h ah=0x88获取内存大小，只能获取64MB
.e820_failed_so_try_e88:
    ;int 15后,ax存入的是以kb为单位的内存容量
    mov ah,0x88
    int 0x15
    jc .error_hlt
    and eax,0x0000FFFF
    mov cx,0x400
    mul cx
    shl edx,16
    or edx,eax
    add edx,0x100000
.error_hlt:
     jmp $
.mem_get_ok:
     mov [total_mem_bytes],edx
   
    
; --------------------------------- 设置进入保护模式 -----------------------------
; 1 打开A20 gate
; 2 加载gdt
; 3 将cr0 的 pe位置1
    
    in al,0x92                 ;端口号0x92 中 第1位变成1即可
    or al,0000_0010b
    out 0x92,al
   
    lgdt [gdt_ptr] 
    
    mov eax,cr0                ;cr0寄存器第0位设置位1
    or  eax,0x00000001              
    mov cr0,eax
      
;-------------------------------- 已经打开保护模式 ---------------------------------------
    jmp dword SELECTOR_CODE:p_mode_start                       ;刷新流水线
 
 [bits 32]
 p_mode_start: 
    mov ax,SELECTOR_DATA
    mov ds,ax
    mov es,ax
    mov ss,ax
    mov esp,LOADER_STACK_TOP
    mov ax,SELECTOR_VIDEO
    mov gs,ax
    
    mov byte [gs:160],'P'
    
    jmp $          
