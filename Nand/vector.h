#ifndef LIBNAND_VECTOR_H
#define LIBNAND_VECTOR_H

typedef struct p {
    void* nand;  // Która bramka
    int input;   // Które wejście w bramce
} pair;

typedef struct vec {
    int k;      // Rzeczywisty rozmiar
    int n;      // Rozmiar będący potęgą 2
    pair* tab;  // Tablica par nandów i inputów
} vector;

vector* new_vector();
void push(vector* vec, void* gate, int a);
void delete(vector* vec);
int pop(vector* vec, int i);

#endif
