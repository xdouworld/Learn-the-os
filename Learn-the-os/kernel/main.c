#include "print.h"
#include "init.h"
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
    put_str("hello os!\n");
    put_str("zt os\n");
    put_int(0x6);
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    put_char('\n');
    
    init_all();
    asm volatile("sti");
    while (1);
    

}
