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
    mov eax,KERNEL_START_SECTOR ;kernel.bin所在扇区号
    mov ebx,KERNEL_BIN_BASE_ADDR ;从磁盘读出后,写入到ebx指定地址
    
    mov ecx,200
    ;----------------暂停------------------------------
    call rd_disk_m_32
    call setup_page
    sgdt [gdt_ptr]
    mov ebx,[gdt_ptr +2]
    or dword [ebx + 0x18 + 4],0xc0000000


    add dword [gdt_ptr + 2],0xc0000000
            
    add esp,0xc0000000
    mov eax,PAGE_DIR_TABLE_POS
    mov cr3,eax

    mov eax,cr0

    or eax,0x80000000

    mov cr0,eax

    lgdt [gdt_ptr]

    jmp SELECTOR_CODE:entry_kernel
entry_kernel:
    call kernel_init
    mov esp,0x009f000
    jmp KERNEL_ENTRY_POINT   ;用地址0x1500访问测试    
;---------------------------------创建页目录及页表--------------------------
setup_page:
;先把页目录占用的空间逐字节清0
    mov ecx, 4096
    mov esi, 0
.clear_page_dir:
    mov byte [PAGE_DIR_TABLE_POS + esi],0
    inc esi
    loop .clear_page_dir

;开始创建目录项
.create_pde:    ;创建page directory entry
    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x1000
    mov ebx,eax

    or eax,PG_US_U | PG_RW_W | PG_P
    ;页目录项的属性RW和P位为1，US为1,表示用户属性，所有的特权级别都可以访问
    mov [PAGE_DIR_TABLE_POS ],eax

    mov [PAGE_DIR_TABLE_POS+0xc00],eax

    sub eax,0x1000
    mov [PAGE_DIR_TABLE_POS + 4092],eax

    mov ecx,256
    mov esi,0
    mov edx,PG_US_U | PG_RW_W | PG_P
.create_pte:
    mov [ebx+esi*4],edx
    add edx,4096
    inc esi
    loop .create_pte

    mov eax,PAGE_DIR_TABLE_POS
    add eax,0x2000
    or eax,PG_US_U | PG_RW_W | PG_P
    mov ebx ,PAGE_DIR_TABLE_POS
    mov ecx,254
    mov esi,769
.create_kernel_pde
    mov [ebx+esi*4],eax
    inc esi
    add eax,0x1000
    loop .create_kernel_pde
    ret
;---------------------kernel.bin中的segment拷贝到编译地址
kernel_init:
    xor eax,eax
    xor ebx,ebx ;ebx记录程序头表地址
    xor ecx,ecx ;cx记录程序头表中的program header数量
    xor edx,edx ;dx记录program header尺寸,即e_phentsize

    mov dx ,[KERNEL_BIN_BASE_ADDR + 42]
    ;偏移位置42字节属性，表示header大小
    mov ebx ,[KERNEL_BIN_BASE_ADDR + 28]

    add ebx,KERNEL_BIN_BASE_ADDR
    mov cx,[KERNEL_BIN_BASE_ADDR+44] ;e_phnum，表示有几个header

.each_segment:
    cmp byte [byte +0],PT_NULL
    je .PTNULL

    ;为函数memcpy压入参数，参数是从右往左
    ;memcpy(dst,src,size)
    push dword [ebx+16]
    mov eax,[ebx+4]
    add eax,KERNEL_BIN_BASE_ADDR

    push eax ;压入函数的memcpy的第二个参数：源地址

    push dword [ebx + 8] ;目的地址

    call mem_cpy
    
    add esp,12
.PTNULL:
    add ebx,edx

    loop .each_segment
    ret


;------------逐字节拷贝mem_cpy(dst,src,size)---------
mem_cpy:
    cld
    push ebp
    mov ebp,esp
    push ecx ;rep指令用于ecx,但ecx对于外层循环还有用

    mov edi, [ebp + 8] ;dst
    mov esi,[ebp + 12] ;src
    mov ecx,[ebp + 16] ;size
    rep movsb     ;逐字节拷贝

    ;恢复环境
    pop ecx
    pop ebp
    ret

rd_disk_m_32:
;------------------------------------------------------------------------
;1 写入待操作磁盘数
;2 写入LBA 低24位寄存器 确认扇区
;3 device 寄存器 第4位主次盘 第6位LBA模式 改为1
;4 command 写指令
;5 读取status状态寄存器 判断是否完成工作
;6 完成工作 取出数据
 
 ;;;;;;;;;;;;;;;;;;;;;
 ;1 写入待操作磁盘数
 ;;;;;;;;;;;;;;;;;;;;;
    mov esi,eax   ; 
    mov di,cx     ; 
    
    mov dx,0x1F2  ; 
    mov al,cl     ; 
    out dx,al     ; 
    
    mov eax,esi   ; 
    
;;;;;;;;;;;;;;;;;;;;;
;2 写入LBA 24位寄存器 确认扇区
;;;;;;;;;;;;;;;;;;;;;


    mov dx,0x1F3  ; LBA low
    out dx,al 
    mov cl,0x8    ; shr 右移8位 把24位给送到 LBA low mid high 寄存器中
    mov dx,0x1F4  ; LBA mid
   
    out dx,al
    shr eax,cl    ; eax为32位 ax为16位 eax的低位字节 右移8位即8~15
    
    mov dx,0x1F5
    shr eax,cl
    out dx,al
    
;;;;;;;;;;;;;;;;;;;;;
;3 device 寄存器 第4位主次盘 第6位LBA模式 改为1
;;;;;;;;;;;;;;;;;;;;;

    		 
    		  ; 24 25 26 27位 尽管我们知道ax只有2 但还是需要按规矩办事 
    		  ; 把除了最后四位的其他位置设置成0
    shr eax,cl
    
    and al,0x0f 
    or al,0xe0   ;!!! 把第四-七位设置成0111 转换为LBA模式
    mov dx,0x1F6 ; 参照硬盘控制器端口表 Device 
    out dx,al

;;;;;;;;;;;;;;;;;;;;;
;4 向Command写操作 Status和Command一个寄存器
;;;;;;;;;;;;;;;;;;;;;

    mov dx,0x1F7 ; Status寄存器端口号
    mov ax,0x20  ; 0x20是读命令
    out dx,al
    
;;;;;;;;;;;;;;;;;;;;;
;5 向Status查看是否准备好惹 
;;;;;;;;;;;;;;;;;;;;;
    
		   ;设置不断读取重复 如果不为1则一直循环
  .not_ready:     
    nop           ; !!! 空跳转指令 在循环中达到延时目的
    in al,dx      ; 把寄存器中的信息返还出来
    and al,0x88   ; !!! 0100 0100 0x88
    cmp al,0x08
    jne .not_ready ; !!! jump not equal == 0
    
;;;;;;;;;;;;;;;;;;;;;
;6 读取数据
;;;;;;;;;;;;;;;;;;;;;

    mov ax,di      ;把 di 储存的cx 取出来
    mov dx,256
    mul dx        ;与di 与 ax 做乘法 计算一共需要读多少次 方便作循环 低16位放ax 高16位放dx
    mov cx,ax      ;loop 与 cx相匹配 cx-- 当cx == 0即跳出循环
    mov dx,0x1F0
 .go_read_loop:
    in ax,dx      ;两字节dx 一次读两字
    mov [ebx],ax
    add ebx,2
    loop .go_read_loop
    
    ret ;与call 配对返回原来的位置 跳转到call下一条指令

