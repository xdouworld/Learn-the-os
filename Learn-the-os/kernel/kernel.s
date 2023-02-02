[bits 32]
%define ERROR_CODE nop		 ; 若在相关的异常中cpu已经自动压入了错误码,为保持栈中格式统一,这里不做操作.
%define ZERO push 0		 ; 若在相关的异常中cpu没有压入错误码,为了统一栈中格式,就手工压入一个0

extern put_str;
extern idt_table;

section .data
global intr_entry_table
intr_entry_table:

%macro VECTOR 2
section .text
intr%1entry:		 ; 每个中断处理程序都要压入中断向量号,所以一个中断类型一个中断处理程序，自己知道自己的中断向量号是多少

   %2				 ; 中断若有错误码会压在eip后面 
; 以下是保存上下文环境
   push ds
   push es
   push fs
   push gs
   pushad			 ; PUSHAD指令压入32位寄存器,其入栈顺序是: EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI

   ; 如果是从片上进入的中断,除了往从片上发送EOI外,还要往主片上发送EOI 
   mov al,0x20                   ; 中断结束命令EOI
   out 0xa0,al                   ; 向从片发送
   out 0x20,al                   ; 向主片发送

   push %1			 ; 不管idt_table中的目标程序是否需要参数,都一律压入中断向量号,调试时很方便
   call [idt_table + %1*4]       ; 调用idt_table中的C版本中断处理函数
   jmp intr_exit
	
section .data
   dd    intr%1entry	 ; 存储各个中断入口程序的地址，形成intr_entry_table数组
%endmacro

section .text
global intr_exit
intr_exit:	     
; 以下是恢复上下文环境
   add esp, 4			   ; 跳过中断号
   popad
   pop gs
   pop fs
   pop es
   pop ds
   add esp, 4			   ; 跳过error_code
   iretd


VECTOR 0x0 ,ZERO
VECTOR 0X1 ,ZERO
VECTOR 0X2 ,ZERO
VECTOR 0x3 ,ZERO
VECTOR 0X4 ,ZERO
VECTOR 0X5 ,ZERO
VECTOR 0x6 ,ZERO
VECTOR 0X7 ,ZERO
VECTOR 0X8 ,ERROR_CODE
VECTOR 0x9 ,ZERO
VECTOR 0XA ,ERROR_CODE
VECTOR 0XB ,ERROR_CODE
VECTOR 0XC ,ERROR_CODE
VECTOR 0XD ,ERROR_CODE
VECTOR 0XE ,ERROR_CODE
VECTOR 0XF ,ZERO
VECTOR 0X10 ,ZERO
VECTOR 0X11 ,ERROR_CODE
VECTOR 0x12 ,ZERO
VECTOR 0X13 ,ZERO
VECTOR 0X14 ,ZERO
VECTOR 0x15 ,ZERO
VECTOR 0X16 ,ZERO
VECTOR 0X17 ,ZERO
VECTOR 0X18 ,ZERO
VECTOR 0X19 ,ZERO
VECTOR 0X1A ,ZERO
VECTOR 0X1B ,ZERO
VECTOR 0X1C ,ZERO
VECTOR 0X1D ,ZERO
VECTOR 0X1E ,ERROR_CODE                               ;处理器自动推错误码
VECTOR 0X1F ,ZERO
VECTOR 0X20 ,ZERO
VECTOR 0X21 ,ZERO					;键盘中断
VECTOR 0X22 ,ZERO					;级联
VECTOR 0X23 ,ZERO					;串口2
VECTOR 0X24 ,ZERO					;串口1
VECTOR 0X25 ,ZERO					;并口2
VECTOR 0X26 ,ZERO					;软盘
VECTOR 0X27 ,ZERO					;并口1
VECTOR 0X28 ,ZERO					;实时时钟
VECTOR 0X29 ,ZERO					;重定向
VECTOR 0X2A ,ZERO					;保留
VECTOR 0x2B ,ZERO					;保留
VECTOR 0x2C ,ZERO					;ps/2 鼠标
VECTOR 0x2D ,ZERO					;fpu 浮点单元异常
VECTOR 0x2E ,ZERO					;硬盘
VECTOR 0x2F ,ZERO					;保留


;;;;;;;;;;;;;;;;   0x80号中断   ;;;;;;;;;;;;;;;;
[bits 32]
extern syscall_table
section .text
global syscall_handler
syscall_handler:
;1 保存上下文环境
   push 0			    ; 压入0, 使栈中格式统一

   push ds
   push es
   push fs
   push gs
   pushad			    ; PUSHAD指令压入32位寄存器，其入栈顺序是:
				    ; EAX,ECX,EDX,EBX,ESP,EBP,ESI,EDI 
				 
   push 0x80			    ; 此位置压入0x80也是为了保持统一的栈格式

;2 为系统调用子功能传入参数
   push edx			    ; 系统调用中第3个参数
   push ecx			    ; 系统调用中第2个参数
   push ebx			    ; 系统调用中第1个参数

;3 调用子功能处理函数
   call [syscall_table + eax*4]	    ; 编译器会在栈中根据C函数声明匹配正确数量的参数
   add esp, 12			    ; 跨过上面的三个参数

;4 将call调用后的返回值存入待当前内核栈中eax的位置
   mov [esp + 8*4], eax	
   jmp intr_exit		    ; intr_exit返回,恢复上下文