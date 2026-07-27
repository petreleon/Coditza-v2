#define _GNU_SOURCE

#include <errno.h>
#include <fcntl.h>
#include <linux/sched.h>
#include <node_api.h>
#include <seccomp.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/prctl.h>
#include <sys/resource.h>
#include <sys/socket.h>
#include <sys/syscall.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static int installed = 0;

static napi_value throw_errno(napi_env env, const char *operation) {
  char message[256];
  snprintf(message, sizeof(message), "%s failed: %s", operation, strerror(errno));
  napi_throw_error(env, NULL, message);
  return NULL;
}

static napi_value throw_seccomp(napi_env env, const char *operation, int result) {
  char message[256];
  snprintf(message, sizeof(message), "%s failed: %s", operation, strerror(-result));
  napi_throw_error(env, NULL, message);
  return NULL;
}

static int add_deny_rule(scmp_filter_ctx context, const char *name, int required) {
  int syscall_number = seccomp_syscall_resolve_name(name);
  if (syscall_number == __NR_SCMP_ERROR) {
    return required ? -ENOSYS : 0;
  }
  return seccomp_rule_add(context, SCMP_ACT_ERRNO(EPERM), syscall_number, 0);
}

static int read_filter_count(int descriptor) {
  char buffer[4096];
  ssize_t bytes;
  char *line;

  if (lseek(descriptor, 0, SEEK_SET) < 0) {
    return -1;
  }
  bytes = read(descriptor, buffer, sizeof(buffer) - 1);
  if (bytes < 0) {
    return -1;
  }
  buffer[bytes] = '\0';
  line = strstr(buffer, "Seccomp_filters:");
  if (line == NULL) {
    errno = EPROTO;
    return -1;
  }
  return atoi(line + strlen("Seccomp_filters:"));
}

static int install_cpu_limit(rlim_t *limit_out) {
  struct rusage usage;
  struct rlimit existing;
  struct rlimit target;
  rlim_t consumed;

  if (getrusage(RUSAGE_SELF, &usage) != 0) {
    return -1;
  }
  if (getrlimit(RLIMIT_CPU, &existing) != 0) {
    return -1;
  }

  consumed = (rlim_t)usage.ru_utime.tv_sec + (rlim_t)usage.ru_stime.tv_sec;
  target.rlim_cur = consumed + 3;
  target.rlim_max = target.rlim_cur + 1;
  if (existing.rlim_max != RLIM_INFINITY && target.rlim_max > existing.rlim_max) {
    target.rlim_max = existing.rlim_max;
    target.rlim_cur = existing.rlim_max > 1 ? existing.rlim_max - 1 : existing.rlim_max;
  }
  if (target.rlim_cur == 0 || target.rlim_max == 0) {
    target.rlim_cur = 1;
    target.rlim_max = 1;
  }
  if (setrlimit(RLIMIT_CPU, &target) != 0) {
    return -1;
  }
  *limit_out = target.rlim_cur;
  return 0;
}

static int require_eprem(int result) {
  return result == -1 && errno == EPERM;
}

static int self_test(void) {
  int descriptor;
  int sockets[2];
  pid_t child;
  int status;
  long raw_result;
  struct clone_args clone_arguments;
  char *const argv[] = {"coditza", NULL};
  char *const envp[] = {NULL};

  errno = 0;
  descriptor = socket(AF_INET, SOCK_STREAM, 0);
  if (descriptor >= 0) {
    close(descriptor);
    return 0;
  }
  if (!require_eprem(descriptor)) {
    return 0;
  }

  errno = 0;
  if (socketpair(-1, SOCK_STREAM, 0, sockets) != -1 || errno != EPERM) {
    return 0;
  }

  errno = 0;
  child = fork();
  if (child == 0) {
    _exit(252);
  }
  if (child > 0) {
    waitpid(child, &status, 0);
    return 0;
  }
  if (!require_eprem(child)) {
    return 0;
  }

  errno = 0;
  child = vfork();
  if (child == 0) {
    _exit(253);
  }
  if (child > 0) {
    waitpid(child, &status, 0);
    return 0;
  }
  if (!require_eprem(child)) {
    return 0;
  }

  errno = 0;
  raw_result = syscall(SYS_clone, CLONE_SIGHAND | SIGCHLD, NULL, NULL, NULL, NULL);
  if (raw_result != -1 || errno != EPERM) {
    return 0;
  }

  memset(&clone_arguments, 0, sizeof(clone_arguments));
  clone_arguments.flags = CLONE_SIGHAND;
  clone_arguments.exit_signal = SIGCHLD;
  errno = 0;
  raw_result = syscall(SYS_clone3, &clone_arguments, sizeof(clone_arguments));
  if (raw_result != -1 || errno != EPERM) {
    return 0;
  }

  errno = 0;
  if (execve("/coditza-seccomp-self-test-not-present", argv, envp) != -1 || errno != EPERM) {
    return 0;
  }

  errno = 0;
  raw_result = syscall(
      SYS_execveat,
      AT_FDCWD,
      "/coditza-seccomp-self-test-not-present",
      argv,
      envp,
      0);
  if (raw_result != -1 || errno != EPERM) {
    return 0;
  }

  errno = 0;
  descriptor = open("/proc/self/status", O_RDONLY);
  if (descriptor >= 0) {
    close(descriptor);
    return 0;
  }
  return require_eprem(descriptor);
}

static napi_value install(napi_env env, napi_callback_info info) {
  static const char *const required_denied_syscalls[] = {
      "clone", "clone3", "execve", "execveat", "socket",
      "socketpair", "connect", "bind", "listen", "accept", "accept4", "sendto",
      "sendmsg", "sendmmsg", "recvfrom", "recvmsg", "recvmmsg", "shutdown",
      "getsockname", "getpeername", "setsockopt", "getsockopt", "openat", "unlinkat",
      "renameat", "mkdirat", "rmdir", "linkat", "symlinkat", "fchmodat", "truncate",
      "ftruncate", "mount", "umount2", "pivot_root",
      "chroot", "setns", "unshare", "ptrace", "process_vm_readv", "process_vm_writev",
      "bpf", "perf_event_open", "reboot", "keyctl", "add_key", "request_key"};
  static const char *const optional_denied_syscalls[] = {
      "fork", "vfork", "open", "creat", "unlink", "rename", "mkdir", "link", "symlink",
      "chmod", "fchmod", "openat2", "renameat2", "fchmodat2", "kexec_load", "kexec_file_load",
      "userfaultfd", "io_uring_setup", "io_uring_enter", "io_uring_register",
      "init_module", "finit_module", "delete_module"};
  scmp_filter_ctx context;
  int status_descriptor = -1;
  int before_filters;
  int after_filters;
  int result;
  size_t index;
  rlim_t cpu_limit;
  napi_value response;
  napi_value value;

  (void)info;
  if (installed) {
    napi_throw_error(env, NULL, "seccomp gate may only be installed once");
    return NULL;
  }
  if (seccomp_arch_native() != SCMP_ARCH_AARCH64) {
    napi_throw_error(env, NULL, "seccomp gate requires Linux arm64");
    return NULL;
  }
  if (install_cpu_limit(&cpu_limit) != 0) {
    return throw_errno(env, "set RLIMIT_CPU");
  }
  status_descriptor = open("/proc/self/status", O_RDONLY | O_CLOEXEC);
  if (status_descriptor < 0) {
    return throw_errno(env, "open seccomp status");
  }
  before_filters = read_filter_count(status_descriptor);
  if (before_filters < 0) {
    close(status_descriptor);
    return throw_errno(env, "read seccomp status");
  }
  if (prctl(PR_SET_NO_NEW_PRIVS, 1, 0, 0, 0) != 0) {
    close(status_descriptor);
    return throw_errno(env, "set no-new-privileges");
  }
  if (prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0) != 1) {
    close(status_descriptor);
    napi_throw_error(env, NULL, "no-new-privileges is not effective");
    return NULL;
  }
  context = seccomp_init(SCMP_ACT_ALLOW);
  if (context == NULL) {
    close(status_descriptor);
    napi_throw_error(env, NULL, "initialize seccomp filter failed");
    return NULL;
  }
  result = seccomp_attr_set(context, SCMP_FLTATR_CTL_TSYNC, 1);
  if (result < 0) {
    seccomp_release(context);
    close(status_descriptor);
    return throw_seccomp(env, "enable seccomp thread synchronization", result);
  }
  for (
      index = 0;
      index < sizeof(required_denied_syscalls) / sizeof(required_denied_syscalls[0]);
      index += 1) {
    result = add_deny_rule(context, required_denied_syscalls[index], 1);
    if (result < 0) {
      seccomp_release(context);
      close(status_descriptor);
      return throw_seccomp(env, "add seccomp deny rule", result);
    }
  }
  for (
      index = 0;
      index < sizeof(optional_denied_syscalls) / sizeof(optional_denied_syscalls[0]);
      index += 1) {
    result = add_deny_rule(context, optional_denied_syscalls[index], 0);
    if (result < 0) {
      seccomp_release(context);
      close(status_descriptor);
      return throw_seccomp(env, "add optional seccomp deny rule", result);
    }
  }
  result = seccomp_load(context);
  seccomp_release(context);
  if (result < 0) {
    close(status_descriptor);
    return throw_seccomp(env, "load seccomp filter", result);
  }
  after_filters = read_filter_count(status_descriptor);
  close(status_descriptor);
  if (after_filters != before_filters + 1) {
    napi_throw_error(env, NULL, "seccomp filter did not become effective");
    return NULL;
  }
  if (!self_test()) {
    napi_throw_error(env, NULL, "seccomp self-test failed closed");
    return NULL;
  }
  installed = 1;

  napi_create_object(env, &response);
  napi_create_string_utf8(env, "aarch64", NAPI_AUTO_LENGTH, &value);
  napi_set_named_property(env, response, "architecture", value);
  napi_get_boolean(env, true, &value);
  napi_set_named_property(env, response, "noNewPrivileges", value);
  napi_get_boolean(env, true, &value);
  napi_set_named_property(env, response, "selfTestPassed", value);
  napi_create_int32(env, after_filters - before_filters, &value);
  napi_set_named_property(env, response, "addedSeccompFilters", value);
  napi_create_double(env, (double)cpu_limit, &value);
  napi_set_named_property(env, response, "cpuHardLimitSeconds", value);
  return response;
}

static napi_value verify(napi_env env, napi_callback_info info) {
  napi_value response;
  napi_value value;

  (void)info;
  if (!installed) {
    napi_throw_error(env, NULL, "seccomp gate is not installed");
    return NULL;
  }
  if (prctl(PR_GET_NO_NEW_PRIVS, 0, 0, 0, 0) != 1) {
    napi_throw_error(env, NULL, "no-new-privileges is not effective in this thread");
    return NULL;
  }
  if (!self_test()) {
    napi_throw_error(env, NULL, "seccomp thread self-test failed closed");
    return NULL;
  }
  napi_create_object(env, &response);
  napi_get_boolean(env, true, &value);
  napi_set_named_property(env, response, "selfTestPassed", value);
  return response;
}

static napi_value initialize(napi_env env, napi_value exports) {
  napi_value install_function;
  napi_value verify_function;
  napi_create_function(env, "install", NAPI_AUTO_LENGTH, install, NULL, &install_function);
  napi_set_named_property(env, exports, "install", install_function);
  napi_create_function(env, "verify", NAPI_AUTO_LENGTH, verify, NULL, &verify_function);
  napi_set_named_property(env, exports, "verify", verify_function);
  return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, initialize)
