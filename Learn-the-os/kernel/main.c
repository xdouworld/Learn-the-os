#include "print.h"
#include "init.h"
#include "debug.h"
#include "thread.h"
#include "interrupt.h"
#include "console.h"
/* 临时为测试添加 */
#include "ioqueue.h"
#include "keyboard.h"
#include "process.h"
void k_thread_a(void*);
void k_thread_b(void*);
void u_prog_a(void);
void u_prog_b(void);
int test_var_a = 0, test_var_b = 0;
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
     thread_start("k_thread_a", 31, k_thread_a, "argA ");
   thread_start("k_thread_b", 31, k_thread_b, "argB ");
   process_execute(u_prog_a, "user_prog_a");
   process_execute(u_prog_b, "user_prog_b");

   intr_enable();	// 打开中断,使时钟中断起作用
   while(1);
    
}

/* 在线程中运行的函数 */
void k_thread_a(void* arg) {     
   char* para = arg;
   while(1) {
      console_put_str(" v_a:0x");
      console_put_int(test_var_a);
   }
}

/* 在线程中运行的函数 */
void k_thread_b(void* arg) {     
   char* para = arg;
   while(1) {
      console_put_str(" v_b:0x");
      console_put_int(test_var_b);
   }
}

/* 测试用户进程 */
void u_prog_a(void) {
   while(1) {
      test_var_a++;
   }
}

/* 测试用户进程 */
void u_prog_b(void) {
   while(1) {
      test_var_b++;
   }
}

