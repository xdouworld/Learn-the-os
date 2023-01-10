#include "print.h"
#include "init.h"
#include "debug.h"
#include "thread.h"
#include "interrupt.h"
#include "console.h"
/* 临时为测试添加 */
#include "ioqueue.h"
#include "keyboard.h"
void k_thread_a(void*);
void k_thread_b(void*);
void main(){
    // put_char('W');
    // put_char('e');
    // put_char('l');
    // put_char('c');
    // put_char('o');
    // put_char('m');
    // put_char('e');
    // put_char(' ');
    // put_char('T');
    // put_char('o');
    // put_char(' ');
    // put_char('Z');
    // put_char('T');
    // put_char('O');
    // put_char('S');
    // put_char('\n');
    put_str("zt os\n");
    init_all();
   intr_enable();	// 打开中断,使时钟中断起作用
   while(1);
    
}

/* 在线程中运行的函数 */
void k_thread_a(void* arg) {     
   while(1) {
      enum intr_status old_status = intr_disable();
      if (!ioq_empty(&kbd_buf)) {
	 console_put_str(arg);
	 char byte = ioq_getchar(&kbd_buf);
	 console_put_char(byte);
      }
      intr_set_status(old_status);
   }
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {     
   while(1) {
      enum intr_status old_status = intr_disable();
      if (!ioq_empty(&kbd_buf)) {
	 console_put_str(arg);
	 char byte = ioq_getchar(&kbd_buf);
	 console_put_char(byte);
      }
      intr_set_status(old_status);
   }
}

