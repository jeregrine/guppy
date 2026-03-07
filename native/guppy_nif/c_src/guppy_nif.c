#include "erl_nif.h"
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

#ifdef __APPLE__
extern int erl_drv_stolen_main_thread_join(ErlNifTid tid, void **respp);
extern int erl_drv_steal_main_thread(char *name, ErlNifTid *dtid,
                                     void *(*func)(void *), void *arg,
                                     ErlNifThreadOpts *opts);
#endif

extern int guppy_rust_ping_value(void);
extern const char *guppy_rust_build_info(void);
extern int guppy_rust_runtime_start(void);
extern int guppy_rust_runtime_shutdown(void);
extern const char *guppy_rust_runtime_status(void);
extern void *guppy_rust_run_hello_window_main_thread(void *arg);
extern int guppy_rust_open_window(uint64_t view_id);
extern int guppy_rust_mount_ir_window(uint64_t view_id, const unsigned char *ir_ptr,
                                      size_t ir_len);
extern int guppy_rust_update_ir_window(uint64_t view_id, const unsigned char *ir_ptr,
                                       size_t ir_len);
extern int guppy_rust_close_window(uint64_t view_id);
extern uint64_t guppy_rust_view_count(void);

void guppy_c_nif_link_anchor(void) {}

static ErlNifMutex *guppy_gui_status_mutex = NULL;
static ErlNifCond *guppy_gui_status_cond = NULL;
static ErlNifMutex *guppy_event_target_mutex = NULL;
static ErlNifTid guppy_gui_thread;
static ErlNifPid guppy_event_target_pid;
static int guppy_gui_status = 0;
static int guppy_gui_started = 0;
static int guppy_event_target_set = 0;

static ERL_NIF_TERM make_atom(ErlNifEnv *env, const char *name) {
  return enif_make_atom(env, name);
}

static ERL_NIF_TERM make_error(ErlNifEnv *env, const char *reason) {
  return enif_make_tuple2(env, make_atom(env, "error"), make_atom(env, reason));
}

static int get_view_id(ErlNifEnv *env, ERL_NIF_TERM term, uint64_t *view_id) {
  ErlNifUInt64 raw_view_id;

  if (!enif_get_uint64(env, term, &raw_view_id)) {
    return 0;
  }

  *view_id = (uint64_t)raw_view_id;
  return 1;
}

void guppy_c_gui_started(int status) {
  if (guppy_gui_status_mutex == NULL || guppy_gui_status_cond == NULL) {
    return;
  }

  enif_mutex_lock(guppy_gui_status_mutex);
  guppy_gui_status = status;
  enif_cond_signal(guppy_gui_status_cond);
  enif_mutex_unlock(guppy_gui_status_mutex);
}

static int send_native_event(ErlNifEnv *msg_env, uint64_t view_id,
                             ERL_NIF_TERM event_term,
                             ERL_NIF_TERM payload_term) {
  ERL_NIF_TERM message;
  ErlNifPid target_pid;
  int has_target = 0;
  int sent;

  if (guppy_event_target_mutex == NULL) {
    return 0;
  }

  enif_mutex_lock(guppy_event_target_mutex);
  if (guppy_event_target_set) {
    target_pid = guppy_event_target_pid;
    has_target = 1;
  }
  enif_mutex_unlock(guppy_event_target_mutex);

  if (!has_target) {
    return 0;
  }

  message = enif_make_tuple4(msg_env, make_atom(msg_env, "guppy_native_event"),
                             enif_make_uint64(msg_env, view_id), event_term,
                             payload_term);

  sent = enif_send(NULL, &target_pid, msg_env, message);
  return sent;
}

int guppy_c_send_click_event(uint64_t view_id, const unsigned char *node_id_ptr,
                             size_t node_id_len,
                             const unsigned char *callback_id_ptr,
                             size_t callback_id_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM keys[2];
  ERL_NIF_TERM values[2];
  unsigned char *node_id_bytes;
  unsigned char *callback_id_bytes;
  int sent;

  msg_env = enif_alloc_env();

  if (msg_env == NULL) {
    return 0;
  }

  node_id_bytes = enif_make_new_binary(msg_env, node_id_len, &node_id_term);

  if (node_id_bytes == NULL) {
    enif_free_env(msg_env);
    return 0;
  }

  memcpy(node_id_bytes, node_id_ptr, node_id_len);

  callback_id_bytes =
      enif_make_new_binary(msg_env, callback_id_len, &callback_id_term);

  if (callback_id_bytes == NULL) {
    enif_free_env(msg_env);
    return 0;
  }

  memcpy(callback_id_bytes, callback_id_ptr, callback_id_len);

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  values[0] = node_id_term;
  values[1] = callback_id_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 2, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "click"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_hover_event(uint64_t view_id, const unsigned char *node_id_ptr,
                             size_t node_id_len,
                             const unsigned char *callback_id_ptr,
                             size_t callback_id_len, int hovered) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM keys[3];
  ERL_NIF_TERM values[3];
  unsigned char *node_id_bytes;
  unsigned char *callback_id_bytes;
  int sent;

  msg_env = enif_alloc_env();

  if (msg_env == NULL) {
    return 0;
  }

  node_id_bytes = enif_make_new_binary(msg_env, node_id_len, &node_id_term);

  if (node_id_bytes == NULL) {
    enif_free_env(msg_env);
    return 0;
  }

  memcpy(node_id_bytes, node_id_ptr, node_id_len);

  callback_id_bytes =
      enif_make_new_binary(msg_env, callback_id_len, &callback_id_term);

  if (callback_id_bytes == NULL) {
    enif_free_env(msg_env);
    return 0;
  }

  memcpy(callback_id_bytes, callback_id_ptr, callback_id_len);

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "hovered");
  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = hovered ? make_atom(msg_env, "true") : make_atom(msg_env, "false");

  if (!enif_make_map_from_arrays(msg_env, keys, values, 3, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "hover"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_window_closed_event(uint64_t view_id) {
  ErlNifEnv *msg_env;
  int sent;

  msg_env = enif_alloc_env();

  if (msg_env == NULL) {
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "window_closed"),
                           make_atom(msg_env, "undefined"));
  enif_free_env(msg_env);
  return sent;
}

static int should_boot_hello_window(void) {
  const char *value = getenv("GUPPY_BOOT_HELLO_WINDOW");
  return value != NULL && strcmp(value, "1") == 0;
}

static int maybe_start_hello_window(void) {
#ifdef __APPLE__
  int result;
  void *arg = should_boot_hello_window() ? (void *)1 : NULL;

  if (guppy_gui_started) {
    return 1;
  }

  guppy_gui_status_mutex = enif_mutex_create((char *)"guppy_gui_status_mutex");
  guppy_gui_status_cond = enif_cond_create((char *)"guppy_gui_status_cond");
  guppy_gui_status = 0;

  result = erl_drv_steal_main_thread((char *)"guppy_gpui", &guppy_gui_thread,
                                     guppy_rust_run_hello_window_main_thread,
                                     arg, NULL);

  if (result != 0) {
    return 0;
  }

  enif_mutex_lock(guppy_gui_status_mutex);
  while (guppy_gui_status == 0) {
    enif_cond_wait(guppy_gui_status_cond, guppy_gui_status_mutex);
  }
  enif_mutex_unlock(guppy_gui_status_mutex);

  guppy_gui_started = guppy_gui_status == 1;
  return guppy_gui_started;
#else
  return 1;
#endif
}

static void maybe_stop_hello_window(void) {
#ifdef __APPLE__
  if (guppy_gui_started) {
    erl_drv_stolen_main_thread_join(guppy_gui_thread, NULL);
    guppy_gui_started = 0;
  }
#endif

  if (guppy_gui_status_mutex != NULL) {
    enif_mutex_destroy(guppy_gui_status_mutex);
    guppy_gui_status_mutex = NULL;
  }

  if (guppy_gui_status_cond != NULL) {
    enif_cond_destroy(guppy_gui_status_cond);
    guppy_gui_status_cond = NULL;
  }

  if (guppy_event_target_mutex != NULL) {
    enif_mutex_destroy(guppy_event_target_mutex);
    guppy_event_target_mutex = NULL;
  }

  guppy_event_target_set = 0;
}

static ERL_NIF_TERM native_ping(ErlNifEnv *env, int argc,
                                const ERL_NIF_TERM argv[]) {
  int ping_value = guppy_rust_ping_value();

  if (ping_value == 1) {
    return make_atom(env, "pong");
  }

  return make_error(env, "rust_core_unavailable");
}

static ERL_NIF_TERM native_build_info(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  const char *info = guppy_rust_build_info();
  return enif_make_string(env, info, ERL_NIF_LATIN1);
}

static ERL_NIF_TERM native_runtime_status(ErlNifEnv *env, int argc,
                                          const ERL_NIF_TERM argv[]) {
  const char *status = guppy_rust_runtime_status();
  return enif_make_string(env, status, ERL_NIF_LATIN1);
}

static ERL_NIF_TERM native_gui_status(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  const char *status = guppy_gui_started ? "started" : "failed";
  return enif_make_string(env, status, ERL_NIF_LATIN1);
}

static ERL_NIF_TERM native_open_window(ErlNifEnv *env, int argc,
                                       const ERL_NIF_TERM argv[]) {
  uint64_t view_id;
  int result;

  if (argc != 1 || !get_view_id(env, argv[0], &view_id)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_open_window(view_id);

  if (result == 1) {
    return make_atom(env, "ok");
  }

  if (result == 0) {
    return make_error(env, "duplicate_view_id");
  }

  return make_error(env, "runtime_unavailable");
}

static ERL_NIF_TERM native_set_event_target(ErlNifEnv *env, int argc,
                                            const ERL_NIF_TERM argv[]) {
  ErlNifPid target_pid;

  if (argc != 1 || !enif_get_local_pid(env, argv[0], &target_pid)) {
    return enif_make_badarg(env);
  }

  if (guppy_event_target_mutex == NULL) {
    return make_error(env, "event_target_unavailable");
  }

  enif_mutex_lock(guppy_event_target_mutex);
  guppy_event_target_pid = target_pid;
  guppy_event_target_set = 1;
  enif_mutex_unlock(guppy_event_target_mutex);

  return make_atom(env, "ok");
}

static int encode_term(ErlNifEnv *env, ERL_NIF_TERM term, ErlNifBinary *binary) {
  return enif_term_to_binary(env, term, binary);
}

static ERL_NIF_TERM native_mount(ErlNifEnv *env, int argc,
                                 const ERL_NIF_TERM argv[]) {
  uint64_t view_id;
  ErlNifBinary ir;
  int result;

  if (argc != 2 || !get_view_id(env, argv[0], &view_id) ||
      !encode_term(env, argv[1], &ir)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_mount_ir_window(view_id, ir.data, ir.size);
  enif_release_binary(&ir);

  if (result == 1) {
    return make_atom(env, "ok");
  }

  if (result == 0) {
    return make_error(env, "unknown_view_id");
  }

  if (result == -2) {
    return enif_make_badarg(env);
  }

  return make_error(env, "runtime_unavailable");
}

static ERL_NIF_TERM native_update(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  uint64_t view_id;
  ErlNifBinary ir;
  int result;

  if (argc != 2 || !get_view_id(env, argv[0], &view_id) ||
      !encode_term(env, argv[1], &ir)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_update_ir_window(view_id, ir.data, ir.size);
  enif_release_binary(&ir);

  if (result == 1) {
    return make_atom(env, "ok");
  }

  if (result == 0) {
    return make_error(env, "unknown_view_id");
  }

  if (result == -2) {
    return enif_make_badarg(env);
  }

  return make_error(env, "runtime_unavailable");
}

static ERL_NIF_TERM native_close_window(ErlNifEnv *env, int argc,
                                        const ERL_NIF_TERM argv[]) {
  uint64_t view_id;
  int result;

  if (argc != 1 || !get_view_id(env, argv[0], &view_id)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_close_window(view_id);

  if (result == 1) {
    return make_atom(env, "ok");
  }

  if (result == 0) {
    return make_error(env, "unknown_view_id");
  }

  return make_error(env, "runtime_unavailable");
}

static ERL_NIF_TERM native_view_count(ErlNifEnv *env, int argc,
                                      const ERL_NIF_TERM argv[]) {
  uint64_t count = guppy_rust_view_count();

  if (count == UINT64_MAX) {
    return make_error(env, "runtime_unavailable");
  }

  return enif_make_uint64(env, count);
}

static int load(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  if (guppy_event_target_mutex == NULL) {
    guppy_event_target_mutex = enif_mutex_create((char *)"guppy_event_target_mutex");
  }

  if (guppy_rust_runtime_start() != 1) {
    return 1;
  }

  if (!maybe_start_hello_window()) {
    return 1;
  }

  return 0;
}

static int reload(ErlNifEnv *env, void **priv_data, ERL_NIF_TERM load_info) {
  return load(env, priv_data, load_info);
}

static int upgrade(ErlNifEnv *env, void **priv_data, void **old_priv_data,
                   ERL_NIF_TERM load_info) {
  return load(env, priv_data, load_info);
}

static void unload(ErlNifEnv *env, void *priv_data) {
  guppy_rust_runtime_shutdown();
  maybe_stop_hello_window();
}

static ErlNifFunc nif_funcs[] = {
    {"native_ping", 0, native_ping, 0},
    {"native_build_info", 0, native_build_info, 0},
    {"native_runtime_status", 0, native_runtime_status, 0},
    {"native_gui_status", 0, native_gui_status, 0},
    {"native_open_window", 1, native_open_window, 0},
    {"native_set_event_target", 1, native_set_event_target, 0},
    {"native_mount", 2, native_mount, 0},
    {"native_update", 2, native_update, 0},
    {"native_close_window", 1, native_close_window, 0},
    {"native_view_count", 0, native_view_count, 0},
};

ERL_NIF_INIT(Elixir.Guppy.Native.Nif, nif_funcs, load, reload, upgrade, unload)
