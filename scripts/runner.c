#define _POSIX_C_SOURCE 200809L
#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <time.h>
#include <unistd.h>

/* Unix resource supervisor. It does not provide a security sandbox. */
static volatile sig_atomic_t interrupted = 0;
static void on_signal(int sig) { interrupted = sig; }
static long long milliseconds(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (long long)t.tv_sec * 1000 + t.tv_nsec / 1000000;
}
static long long positive(const char *s) {
    char *end;
    errno = 0;
    long long n = strtoll(s, &end, 10);
    if (errno || *end || n <= 0) return -1;
    return n;
}
static int write_all(int fd, const char *buffer, size_t len) {
    while (len) {
        ssize_t n = write(fd, buffer, len);
        if (n < 0 && errno == EINTR) continue;
        if (n <= 0) return -1;
        buffer += n;
        len -= (size_t)n;
    }
    return 0;
}
int main(int argc, char **argv) {
    if (argc < 9 || strcmp(argv[7], "--")) {
        fputs("usage: runner timeout-ms log-bytes cwd stdout stderr result -- program args\n", stderr);
        return 2;
    }
    const long long timeout = positive(argv[1]), limit = positive(argv[2]);
    if (timeout < 0 || limit < 0) return 2;
    int logs[2] = {open(argv[4], O_WRONLY | O_CREAT | O_EXCL, 0600), open(argv[5], O_WRONLY | O_CREAT | O_EXCL, 0600)};
    if (logs[0] < 0 || logs[1] < 0) { perror("open evidence logs"); return 2; }
    int pipes[2][2];
    if (pipe(pipes[0]) || pipe(pipes[1])) { perror("pipe"); return 2; }
    struct sigaction action;
    memset(&action, 0, sizeof(action));
    action.sa_handler = on_signal;
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);
    const pid_t supervisor_parent = getppid();
    const long long started = milliseconds();
    pid_t child = fork();
    if (child < 0) { perror("fork"); return 2; }
    if (child == 0) {
        signal(SIGINT, SIG_DFL);
        signal(SIGTERM, SIG_DFL);
        signal(SIGHUP, SIG_DFL);
        if (setsid() < 0) _exit(126);
        close(pipes[0][0]); close(pipes[1][0]);
        dup2(pipes[0][1], STDOUT_FILENO); dup2(pipes[1][1], STDERR_FILENO);
        close(pipes[0][1]); close(pipes[1][1]); close(logs[0]); close(logs[1]);
        int input = open("/dev/null", O_RDONLY);
        if (input >= 0) { dup2(input, STDIN_FILENO); close(input); }
        if (chdir(argv[3]) < 0) { perror("chdir"); _exit(126); }
        execvp(argv[8], &argv[8]);
        perror("exec"); _exit(127);
    }
    close(pipes[0][1]); close(pipes[1][1]);
    for (int i = 0; i < 2; i++) fcntl(pipes[i][0], F_SETFL, O_NONBLOCK);
    int alive[2] = {1, 1}, status = 0, done = 0, killed = 0, timed_out = 0, truncated = 0, io_error = 0;
    long long written = 0;
    while (!done || alive[0] || alive[1]) {
        if (getppid() != supervisor_parent && !interrupted) interrupted = SIGTERM;
        if (!done && milliseconds() - started >= timeout) timed_out = 1;
        if (!killed && (timed_out || truncated || interrupted || io_error)) {
            kill(-child, SIGKILL); kill(child, SIGKILL); killed = 1;
        }
        struct pollfd fds[2] = {{pipes[0][0], POLLIN, 0}, {pipes[1][0], POLLIN, 0}};
        poll(fds, 2, 10);
        for (int i = 0; i < 2; i++) {
            if (!alive[i]) continue;
            char buffer[8192];
            for (;;) {
                ssize_t n = read(pipes[i][0], buffer, sizeof(buffer));
                if (n == 0) { alive[i] = 0; close(pipes[i][0]); break; }
                if (n < 0) {
                    if (errno == EINTR) continue;
                    if (errno != EAGAIN && errno != EWOULDBLOCK) io_error = 1;
                    break;
                }
                long long keep = n;
                if (keep > limit - written) { keep = limit - written; truncated = 1; }
                if (keep > 0 && write_all(logs[i], buffer, (size_t)keep)) io_error = 1;
                written += keep;
                if (truncated && !killed) { kill(-child, SIGKILL); kill(child, SIGKILL); killed = 1; }
            }
        }
        if (!done) {
            pid_t r = waitpid(child, &status, WNOHANG);
            if (r == child) {
                done = 1;
                /* A normal parent exit must not leave descendants holding pipes. */
                kill(-child, SIGKILL);
            } else if (r < 0 && errno != EINTR) { io_error = 1; done = 1; }
        }
        if (done && milliseconds() - started > timeout + 3000) { io_error = 1; break; }
    }
    for (int i = 0; i < 2; i++) { fsync(logs[i]); close(logs[i]); }
    int code = WIFEXITED(status) ? WEXITSTATUS(status) : 128 + (WIFSIGNALED(status) ? WTERMSIG(status) : 0);
    if ((timed_out || truncated || interrupted || io_error) && code == 0) code = 125;
    FILE *result = fopen(argv[6], "wx");
    if (!result) { perror("write result"); return 2; }
    int r = fprintf(result, "{\"exit_code\":%d,\"timed_out\":%s,\"truncated\":%s,\"interrupted\":%s,\"io_error\":%s,\"elapsed_ms\":%lld,\"pid\":%ld}\n",
        code, timed_out ? "true" : "false", truncated ? "true" : "false", interrupted ? "true" : "false", io_error ? "true" : "false", milliseconds() - started, (long)child);
    if (fclose(result) || r < 0 || io_error) return 2;
    return 0;
}
