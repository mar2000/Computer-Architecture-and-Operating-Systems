#include "vector.h"
#include <errno.h>
#include <memory.h>
#include <stdlib.h>

	// Tworzenie nowego wektora
vector* new_vector() {
    vector* vec = (vector*)malloc(sizeof(vector));
    if (vec == NULL) {
        errno = ENOMEM;
        return NULL;
    }

    vec->n = 1;
    vec->k = 0;
    vec->tab = (pair*)calloc(1, sizeof(pair));
    if (vec->tab == NULL) {
        errno = ENOMEM;
        return NULL;
    }

    return vec;
}

	// Dodawanie brami na wektor - Jeśli nie ma miejsca na wektorze to powiększamy jego rozmiar. Następnie 
	// dodajemy element na wektor.
void push(vector* vec, void* gate, int a) {
    if (vec->k + 1 >= vec->n) {
        pair* new_tab = (pair*)calloc((2 * vec->n), sizeof(pair));
        if (new_tab == NULL) {
            errno = ENOMEM;
            return;
        }
        memcpy(new_tab, vec->tab, (vec->n) * sizeof(pair));
        free(vec->tab);
        vec->tab = new_tab;
        vec->n = 2 * vec->n;
    }

    vec->tab[vec->k].nand = gate;
    vec->tab[vec->k].input = a;
    vec->k++;
}

	// Usuwanie wekrora 
void delete(vector* vec) {
	if (!vec) {
		return;	
	}

	if (vec->tab) {
	    free(vec->tab);	
	}

    free(vec);
}

	// Usuwanie elementu z wektora - Przesuwamy ostatni element z wektora na miejse usuwanej bramki. 
int pop(vector* vec, int i) {
    if (vec->k == 0) {
        return -1;
    }

    vec->k--;
    vec->tab[i].nand = vec->tab[vec->k].nand;
    vec->tab[i].input = vec->tab[vec->k].input;

    return 0;
}
