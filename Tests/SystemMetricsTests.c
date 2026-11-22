#include <assert.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

extern uint64_t sos_process_tree_bytes(int32_t, int32_t);
extern uint64_t sos_available_memory_bytes(void);
extern int32_t sos_free_local_port(void);

int main(void) {
    int ready[2], finish[2]; assert(pipe(ready) == 0 && pipe(finish) == 0);
    pid_t child = fork(); assert(child >= 0);
    if (child == 0) {
        close(ready[0]); close(finish[1]);
        volatile unsigned char *memory = malloc(64 * 1024 * 1024);
        assert(memory);
        for (size_t n = 0; n < 64 * 1024 * 1024; n += 4096) memory[n] = 42;
        assert(write(ready[1], "x", 1) == 1);
        char byte; read(finish[0], &byte, 1);
        free((void *)memory); _exit(0);
    }
    close(ready[1]); close(finish[0]); char byte;
    assert(read(ready[0], &byte, 1) == 1);
    uint64_t nested = sos_process_tree_bytes(child, 0);
    uint64_t total = sos_process_tree_bytes(getpid(), 0);
    printf("Child footprint: %llu; process tree: %llu\n", nested, total);
    assert(write(finish[1], "x", 1) == 1); waitpid(child, NULL, 0);
    assert(nested > 40 * 1024 * 1024 && total >= nested);
    assert(sos_available_memory_bytes() > 0);
    assert(sos_free_local_port() > 1024);
    puts("PASS: real child memory included; available memory and private local port measured");
}
