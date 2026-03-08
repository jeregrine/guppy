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
extern void *guppy_rust_run_main_thread_runtime(void *arg);
extern int guppy_rust_open_window(uint64_t view_id,
                                  const unsigned char *ir_ptr,
                                  size_t ir_len,
                                  const unsigned char *opts_ptr,
                                  size_t opts_len);
extern int guppy_rust_render_ir_window(uint64_t view_id,
                                       const unsigned char *ir_ptr,
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

static int encode_term(ErlNifEnv *env, ERL_NIF_TERM term, ErlNifBinary *binary);

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

static ERL_NIF_TERM make_bool(ErlNifEnv *env, int value) {
  return value ? make_atom(env, "true") : make_atom(env, "false");
}

static ERL_NIF_TERM make_mouse_button_term(ErlNifEnv *env, int button_code) {
  switch (button_code) {
  case 1:
    return make_atom(env, "left");
  case 2:
    return make_atom(env, "right");
  case 3:
    return make_atom(env, "middle");
  case 4:
    return make_atom(env, "navigate_back");
  case 5:
    return make_atom(env, "navigate_forward");
  default:
    return make_atom(env, "nil");
  }
}

static int make_modifiers_map(ErlNifEnv *env, int control, int alt, int shift,
                              int platform, int function,
                              ERL_NIF_TERM *modifiers_term) {
  ERL_NIF_TERM keys[5];
  ERL_NIF_TERM values[5];

  keys[0] = make_atom(env, "control");
  keys[1] = make_atom(env, "alt");
  keys[2] = make_atom(env, "shift");
  keys[3] = make_atom(env, "platform");
  keys[4] = make_atom(env, "function");

  values[0] = make_bool(env, control);
  values[1] = make_bool(env, alt);
  values[2] = make_bool(env, shift);
  values[3] = make_bool(env, platform);
  values[4] = make_bool(env, function);

  return enif_make_map_from_arrays(env, keys, values, 5, modifiers_term);
}

static int make_id_callback_terms(ErlNifEnv *env, const unsigned char *node_id_ptr,
                                  size_t node_id_len,
                                  const unsigned char *callback_id_ptr,
                                  size_t callback_id_len,
                                  ERL_NIF_TERM *node_id_term,
                                  ERL_NIF_TERM *callback_id_term) {
  unsigned char *node_id_bytes;
  unsigned char *callback_id_bytes;

  node_id_bytes = enif_make_new_binary(env, node_id_len, node_id_term);

  if (node_id_bytes == NULL) {
    return 0;
  }

  memcpy(node_id_bytes, node_id_ptr, node_id_len);

  callback_id_bytes =
      enif_make_new_binary(env, callback_id_len, callback_id_term);

  if (callback_id_bytes == NULL) {
    return 0;
  }

  memcpy(callback_id_bytes, callback_id_ptr, callback_id_len);
  return 1;
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

static int make_binary_term(ErlNifEnv *env, const unsigned char *ptr, size_t len,
                            ERL_NIF_TERM *term) {
  unsigned char *bytes = enif_make_new_binary(env, len, term);

  if (bytes == NULL) {
    return 0;
  }

  memcpy(bytes, ptr, len);
  return 1;
}

int guppy_c_send_change_event(uint64_t view_id, const unsigned char *node_id_ptr,
                              size_t node_id_len,
                              const unsigned char *callback_id_ptr,
                              size_t callback_id_len,
                              const unsigned char *value_ptr,
                              size_t value_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM value_term;
  ERL_NIF_TERM keys[3];
  ERL_NIF_TERM values[3];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, value_ptr, value_len, &value_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "value");
  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = value_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 3, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "change"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_checkbox_change_event(uint64_t view_id,
                                       const unsigned char *node_id_ptr,
                                       size_t node_id_len,
                                       const unsigned char *callback_id_ptr,
                                       size_t callback_id_len, int checked) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM keys[3];
  ERL_NIF_TERM values[3];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "checked");
  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = make_bool(msg_env, checked);

  if (!enif_make_map_from_arrays(msg_env, keys, values, 3, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "change"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_focus_event(uint64_t view_id, const unsigned char *node_id_ptr,
                             size_t node_id_len,
                             const unsigned char *callback_id_ptr,
                             size_t callback_id_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM keys[2];
  ERL_NIF_TERM values[2];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  values[0] = node_id_term;
  values[1] = callback_id_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 2, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "focus"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_blur_event(uint64_t view_id, const unsigned char *node_id_ptr,
                            size_t node_id_len,
                            const unsigned char *callback_id_ptr,
                            size_t callback_id_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM keys[2];
  ERL_NIF_TERM values[2];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  values[0] = node_id_term;
  values[1] = callback_id_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 2, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "blur"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_key_down_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *key_ptr, size_t key_len,
    const unsigned char *key_char_ptr, size_t key_char_len, int has_key_char,
    int is_held, int control, int alt, int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM key_term;
  ERL_NIF_TERM key_char_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[6];
  ERL_NIF_TERM values[6];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, key_ptr, key_len, &key_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  if (has_key_char) {
    if (!make_binary_term(msg_env, key_char_ptr, key_char_len, &key_char_term)) {
      enif_free_env(msg_env);
      return 0;
    }
  } else {
    key_char_term = make_atom(msg_env, "nil");
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "key");
  keys[3] = make_atom(msg_env, "key_char");
  keys[4] = make_atom(msg_env, "is_held");
  keys[5] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = key_term;
  values[3] = key_char_term;
  values[4] = make_bool(msg_env, is_held);
  values[5] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 6, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "key_down"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_key_up_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *key_ptr, size_t key_len,
    const unsigned char *key_char_ptr, size_t key_char_len, int has_key_char,
    int control, int alt, int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM key_term;
  ERL_NIF_TERM key_char_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[5];
  ERL_NIF_TERM values[5];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, key_ptr, key_len, &key_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  if (has_key_char) {
    if (!make_binary_term(msg_env, key_char_ptr, key_char_len, &key_char_term)) {
      enif_free_env(msg_env);
      return 0;
    }
  } else {
    key_char_term = make_atom(msg_env, "nil");
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "key");
  keys[3] = make_atom(msg_env, "key_char");
  keys[4] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = key_term;
  values[3] = key_char_term;
  values[4] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 5, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "key_up"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_action_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *action_ptr, size_t action_len,
    const unsigned char *shortcut_ptr, size_t shortcut_len,
    const unsigned char *key_ptr, size_t key_len,
    const unsigned char *key_char_ptr, size_t key_char_len, int has_key_char,
    int control, int alt, int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM action_term;
  ERL_NIF_TERM shortcut_term;
  ERL_NIF_TERM key_term;
  ERL_NIF_TERM key_char_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[7];
  ERL_NIF_TERM values[7];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, action_ptr, action_len, &action_term) ||
      !make_binary_term(msg_env, shortcut_ptr, shortcut_len, &shortcut_term) ||
      !make_binary_term(msg_env, key_ptr, key_len, &key_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  if (has_key_char) {
    if (!make_binary_term(msg_env, key_char_ptr, key_char_len, &key_char_term)) {
      enif_free_env(msg_env);
      return 0;
    }
  } else {
    key_char_term = make_atom(msg_env, "nil");
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "action");
  keys[3] = make_atom(msg_env, "shortcut");
  keys[4] = make_atom(msg_env, "key");
  keys[5] = make_atom(msg_env, "key_char");
  keys[6] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = action_term;
  values[3] = shortcut_term;
  values[4] = key_term;
  values[5] = key_char_term;
  values[6] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 7, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "action"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_context_menu_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    double x, double y, int control, int alt, int shift, int platform,
    int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[5];
  ERL_NIF_TERM values[5];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "x");
  keys[3] = make_atom(msg_env, "y");
  keys[4] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = enif_make_double(msg_env, x);
  values[3] = enif_make_double(msg_env, y);
  values[4] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 5, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id,
                           make_atom(msg_env, "context_menu"), payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_drag_start_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *source_id_ptr, size_t source_id_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM source_id_term;
  ERL_NIF_TERM keys[3];
  ERL_NIF_TERM values[3];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, source_id_ptr, source_id_len,
                        &source_id_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "source_id");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = source_id_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 3, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "drag_start"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_drag_move_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *source_id_ptr, size_t source_id_len,
    int pressed_button_code, double x, double y, int control, int alt,
    int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM source_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[7];
  ERL_NIF_TERM values[7];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, source_id_ptr, source_id_len,
                        &source_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "source_id");
  keys[3] = make_atom(msg_env, "pressed_button");
  keys[4] = make_atom(msg_env, "x");
  keys[5] = make_atom(msg_env, "y");
  keys[6] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = source_id_term;
  values[3] = make_mouse_button_term(msg_env, pressed_button_code);
  values[4] = enif_make_double(msg_env, x);
  values[5] = enif_make_double(msg_env, y);
  values[6] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 7, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "drag_move"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_drop_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    const unsigned char *source_id_ptr, size_t source_id_len) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM source_id_term;
  ERL_NIF_TERM keys[3];
  ERL_NIF_TERM values[3];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_binary_term(msg_env, source_id_ptr, source_id_len,
                        &source_id_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "source_id");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = source_id_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 3, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "drop"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_mouse_down_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    int button_code, double x, double y, uint64_t click_count, int control,
    int alt, int shift, int platform, int function, int first_mouse) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[8];
  ERL_NIF_TERM values[8];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "button");
  keys[3] = make_atom(msg_env, "x");
  keys[4] = make_atom(msg_env, "y");
  keys[5] = make_atom(msg_env, "click_count");
  keys[6] = make_atom(msg_env, "first_mouse");
  keys[7] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = make_mouse_button_term(msg_env, button_code);
  values[3] = enif_make_double(msg_env, x);
  values[4] = enif_make_double(msg_env, y);
  values[5] = enif_make_uint64(msg_env, click_count);
  values[6] = make_bool(msg_env, first_mouse);
  values[7] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 8, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "mouse_down"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_mouse_up_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    int button_code, double x, double y, uint64_t click_count, int control,
    int alt, int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[7];
  ERL_NIF_TERM values[7];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "button");
  keys[3] = make_atom(msg_env, "x");
  keys[4] = make_atom(msg_env, "y");
  keys[5] = make_atom(msg_env, "click_count");
  keys[6] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = make_mouse_button_term(msg_env, button_code);
  values[3] = enif_make_double(msg_env, x);
  values[4] = enif_make_double(msg_env, y);
  values[5] = enif_make_uint64(msg_env, click_count);
  values[6] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 7, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "mouse_up"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_mouse_move_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    int pressed_button_code, double x, double y, int control, int alt,
    int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[6];
  ERL_NIF_TERM values[6];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "pressed_button");
  keys[3] = make_atom(msg_env, "x");
  keys[4] = make_atom(msg_env, "y");
  keys[5] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = make_mouse_button_term(msg_env, pressed_button_code);
  values[3] = enif_make_double(msg_env, x);
  values[4] = enif_make_double(msg_env, y);
  values[5] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 6, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id, make_atom(msg_env, "mouse_move"),
                           payload_term);
  enif_free_env(msg_env);
  return sent;
}

int guppy_c_send_scroll_wheel_event(
    uint64_t view_id, const unsigned char *node_id_ptr, size_t node_id_len,
    const unsigned char *callback_id_ptr, size_t callback_id_len,
    double x, double y, int delta_kind_code, double delta_x, double delta_y,
    int control, int alt, int shift, int platform, int function) {
  ErlNifEnv *msg_env;
  ERL_NIF_TERM payload_term;
  ERL_NIF_TERM node_id_term;
  ERL_NIF_TERM callback_id_term;
  ERL_NIF_TERM modifiers_term;
  ERL_NIF_TERM keys[8];
  ERL_NIF_TERM values[8];
  int sent;

  msg_env = enif_alloc_env();
  if (msg_env == NULL) {
    return 0;
  }

  if (!make_id_callback_terms(msg_env, node_id_ptr, node_id_len,
                              callback_id_ptr, callback_id_len,
                              &node_id_term, &callback_id_term) ||
      !make_modifiers_map(msg_env, control, alt, shift, platform, function,
                          &modifiers_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  keys[0] = make_atom(msg_env, "id");
  keys[1] = make_atom(msg_env, "callback");
  keys[2] = make_atom(msg_env, "x");
  keys[3] = make_atom(msg_env, "y");
  keys[4] = make_atom(msg_env, "delta_kind");
  keys[5] = make_atom(msg_env, "delta_x");
  keys[6] = make_atom(msg_env, "delta_y");
  keys[7] = make_atom(msg_env, "modifiers");

  values[0] = node_id_term;
  values[1] = callback_id_term;
  values[2] = enif_make_double(msg_env, x);
  values[3] = enif_make_double(msg_env, y);
  values[4] = delta_kind_code == 1 ? make_atom(msg_env, "pixels")
                                   : make_atom(msg_env, "lines");
  values[5] = enif_make_double(msg_env, delta_x);
  values[6] = enif_make_double(msg_env, delta_y);
  values[7] = modifiers_term;

  if (!enif_make_map_from_arrays(msg_env, keys, values, 8, &payload_term)) {
    enif_free_env(msg_env);
    return 0;
  }

  sent = send_native_event(msg_env, view_id,
                           make_atom(msg_env, "scroll_wheel"), payload_term);
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

static int maybe_start_main_thread_runtime(void) {
#ifdef __APPLE__
  int result;

  if (guppy_gui_started) {
    return 1;
  }

  guppy_gui_status_mutex = enif_mutex_create((char *)"guppy_gui_status_mutex");
  guppy_gui_status_cond = enif_cond_create((char *)"guppy_gui_status_cond");
  guppy_gui_status = 0;

  result = erl_drv_steal_main_thread((char *)"guppy_gpui", &guppy_gui_thread,
                                     guppy_rust_run_main_thread_runtime,
                                     NULL, NULL);

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
  guppy_gui_started = 1;
  return 1;
#endif
}

static void maybe_stop_main_thread_runtime(void) {
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
  ErlNifBinary ir;
  ErlNifBinary opts;
  int result;

  if (argc != 3 || !get_view_id(env, argv[0], &view_id) ||
      !encode_term(env, argv[1], &ir) || !encode_term(env, argv[2], &opts)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_open_window(view_id, ir.data, ir.size, opts.data, opts.size);
  enif_release_binary(&ir);
  enif_release_binary(&opts);

  if (result == 1) {
    return make_atom(env, "ok");
  }

  if (result == 0) {
    return make_error(env, "duplicate_view_id");
  }

  if (result == -2) {
    return enif_make_badarg(env);
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

static ERL_NIF_TERM native_render(ErlNifEnv *env, int argc,
                                  const ERL_NIF_TERM argv[]) {
  uint64_t view_id;
  ErlNifBinary ir;
  int result;

  if (argc != 2 || !get_view_id(env, argv[0], &view_id) ||
      !encode_term(env, argv[1], &ir)) {
    return enif_make_badarg(env);
  }

  result = guppy_rust_render_ir_window(view_id, ir.data, ir.size);
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

  if (!maybe_start_main_thread_runtime()) {
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
  maybe_stop_main_thread_runtime();
}

static ErlNifFunc nif_funcs[] = {
    {"native_ping", 0, native_ping, 0},
    {"native_build_info", 0, native_build_info, 0},
    {"native_runtime_status", 0, native_runtime_status, 0},
    {"native_gui_status", 0, native_gui_status, 0},
    {"native_open_window", 3, native_open_window, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"native_set_event_target", 1, native_set_event_target, 0},
    {"native_render", 2, native_render, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"native_close_window", 1, native_close_window, ERL_NIF_DIRTY_JOB_IO_BOUND},
    {"native_view_count", 0, native_view_count, ERL_NIF_DIRTY_JOB_IO_BOUND},
};

ERL_NIF_INIT(Elixir.Guppy.Native.Nif, nif_funcs, load, reload, upgrade, unload)
