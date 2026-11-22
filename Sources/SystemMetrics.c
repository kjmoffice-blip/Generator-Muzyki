#include <libproc.h>
#include <mach/mach.h>
#include <stdint.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <unistd.h>

/* Physical footprint includes memory charged to each owned process by macOS. */
uint64_t sos_process_tree_bytes(int32_t pid, int32_t depth) {
    if (pid <= 0 || depth > 16) return 0;
    struct rusage_info_v4 info = {0};
    uint64_t total = 0;
    if (proc_pid_rusage(pid, RUSAGE_INFO_V4, (rusage_info_t *)&info) == 0)
        total = info.ri_phys_footprint;
    int capacity = proc_listchildpids(pid, NULL, 0);
    if (capacity <= 0) return total;
    capacity = (capacity + 32) * (int)sizeof(pid_t);
    pid_t *children = calloc(1, (size_t)capacity);
    if (!children) return total;
    int count = proc_listchildpids(pid, children, capacity);
    for (int i = 0; i < count && i < capacity / (int)sizeof(pid_t); i++)
        if (children[i] > 0 && children[i] != pid)
            total += sos_process_tree_bytes(children[i], depth + 1);
    free(children);
    return total;
}

/* Inactive pages are reclaimable; speculative pages already count as free. */
uint64_t sos_available_memory_bytes(void) {
    vm_statistics64_data_t stats = {0};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    vm_size_t page_size = 0;
    host_page_size(mach_host_self(), &page_size);
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64,
                          (host_info64_t)&stats, &count) != KERN_SUCCESS) return 0;
    return ((uint64_t)stats.free_count + stats.inactive_count) * page_size;
}

int32_t sos_free_local_port(void) {
    int fd = socket(AF_INET, SOCK_STREAM, 0);
    if (fd < 0) return 0;
    struct sockaddr_in address = {0};
    address.sin_len = sizeof(address); address.sin_family = AF_INET;
    address.sin_addr.s_addr = htonl(INADDR_LOOPBACK); address.sin_port = 0;
    int32_t port = 0;
    socklen_t length = sizeof(address);
    if (bind(fd, (struct sockaddr *)&address, sizeof(address)) == 0 &&
        getsockname(fd, (struct sockaddr *)&address, &length) == 0) port = ntohs(address.sin_port);
    close(fd);
    return port;
}
