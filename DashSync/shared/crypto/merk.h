#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Element {
  uintptr_t key_length;
  uint8_t *key;
  bool bool_;
  uintptr_t value_length;
  uint8_t *value;
} Element;

typedef struct ExecuteProofResult {
  uint8_t (*hash)[32];
  uintptr_t element_count;
  struct Element **elements;
} ExecuteProofResult;

const struct ExecuteProofResult *execute_proof_c(const uint8_t *c_array, uintptr_t length);
