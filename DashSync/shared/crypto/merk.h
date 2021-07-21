#ifndef merk_h
#define merk_h

#include <stdarg.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct Element {
  const uint8_t *key;
  bool bool_;
  uintptr_t value_length;
  const uint8_t *value;
} Element;

typedef struct ExecuteProofResult {
  const uint8_t *hash;
  uintptr_t element_count;
  struct Element *const *elements;
} ExecuteProofResult;

const struct ExecuteProofResult *execute_proof_c(const uint8_t *c_array);

#endif /* merk_h */
