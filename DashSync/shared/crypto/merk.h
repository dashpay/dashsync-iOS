#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Element {
  uintptr_t key_length;
  uint8_t *key;
  bool exists;
  uintptr_t value_length;
  uint8_t *value;
} Element;

typedef struct ExecuteProofResult {
  bool valid;
  uint8_t (*hash)[32];
  uintptr_t element_count;
  struct Element **elements;
} ExecuteProofResult;

typedef struct Query {
  uintptr_t key_length;
  uint8_t *key;
  uintptr_t key_end_length;
  uint8_t *key_end;
} Query;

typedef struct Keys {
  uintptr_t element_count;
  struct Query **elements;
} Keys;

struct ExecuteProofResult *execute_proof_c(const uint8_t *c_array, uintptr_t length);

struct ExecuteProofResult *execute_proof_query_keys_c(const uint8_t *c_array,
                                                      uintptr_t length,
                                                      const struct Keys *query_keys);

void destroy_proof_c(struct ExecuteProofResult *proof_result);
