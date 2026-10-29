/* Only bridge POSIX signals into a flag; HTTP and application logic are Cangjie. */
#define _POSIX_C_SOURCE 200809L
#include <signal.h>
#include <stdint.h>
#include <errno.h>
#include <unistd.h>
static volatile sig_atomic_t stop_signal = 0;
static void request_stop(int signum) { stop_signal = signum; }
int cjdg_install_signals(void) {
    struct sigaction action = {0};
    action.sa_handler = request_stop;
    sigemptyset(&action.sa_mask);
    if (sigaction(SIGINT, &action, 0) || sigaction(SIGTERM, &action, 0) || sigaction(SIGHUP, &action, 0)) return -1;
    return 0;
}
int cjdg_stop_requested(void) { return (int)stop_signal; }

/* A PID which has been reused is alive, so recovery conservatively refuses it. */
int cjdg_pid_state(int64_t pid) {
    if (pid <= 0 || pid > INT32_MAX) return -1;
    if (kill((pid_t)pid, 0) == 0) return 1;
    return errno == ESRCH ? 0 : -1;
}
