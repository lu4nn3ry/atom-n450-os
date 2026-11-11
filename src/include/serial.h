#ifndef _SERIAL_H_
#define _SERIAL_H_

#include "types.h"

#define COM1_PORT 0x3F8

void serial_init(void);
void serial_write_char(char c);
void serial_write_string(const char* str);
void serial_write_hex(uint64_t val);

#endif
