#include "print.h"
#include "init.h"
#include "debug.h"
#include "thread.h"
#include "interrupt.h"
#include "console.h"
//void k_thread_a(void*);
//void k_thread_b(void*);
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


