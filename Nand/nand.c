#include "vector.h"
#include "nand.h"
#include <errno.h>
#include <malloc.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdio.h>
#include <unistd.h>
#include <assert.h>


	// Struktura reprezentująca bramkę logiczną
typedef struct nand {
    bool output;                            // Wartość bramki na wyjściu
    bool **inputs_bool;                     // Tablica podłączonych sygnałów od generatora do wejścia
    struct nand **inputs_nand;              // Tablica podłączonych nandów do wejścia
    unsigned int inputs_count;              // Liczba wejść
    vector *output_nands;                   // Tablica bramek do których wchodzimy z wyjścia
    int visited;                            // Informacja o stanie odwiedzenia w DFS - 0|1|2 = nieodwiedzony|w trakcie|odwiedzony
} nand_t;

	// Funkcja tworząda nową bramkę - Tworzymy bramkę i ustawiamy początkowe wartości poszczególnych elementów bramki.
	// W przypadku niepowodzenia ustawiamy errno na ENOMEN.
nand_t *nand_new(unsigned n) {
    nand_t *gate = (nand_t *)malloc(sizeof(nand_t));
    if (gate == NULL) {
        errno = ENOMEM;
        return NULL;
    }
    gate->inputs_count = (int)n;
    gate->inputs_bool = (bool **)calloc(n, sizeof(bool *));
    if (gate->inputs_bool == NULL) {
        errno = ENOMEM;
        return NULL;
    }
    gate->inputs_nand = (nand_t **)calloc(n, sizeof(nand_t *));
    if (gate->inputs_nand == NULL) {
        errno = ENOMEM;
        return NULL;
    }
    gate->output_nands = new_vector();
    gate->visited = 0;
    gate->output = 0;
    return gate;
}

	// Funkcja usuwająca bramkę - Na początku zajmujemy się wyjściem czyli usuwamy siebie z tablicy wejść naszych sąsiadów 
	// do których wchodzimy, następnie zajmujemy się wejściem, czyli usuwamy siebie z wektora sąsiadów które do nas wchodzą.
	// Jeśli bramka jest NULLem to returnujemy.
void nand_delete(nand_t *g) {
    if (g == NULL) {
        return;
    }

    // Usuwanie połączeń z wyjścia
    int m;
    m = g->output_nands->k;
    for (int i = 0; i < m; i++) {
        nand_t *out_gate = g->output_nands->tab[i].nand;
        int out_k = g->output_nands->tab[i].input;
        out_gate->inputs_nand[out_k] = NULL;
    }

    // Usuwanie siebie z wyjścia sąsiadów, które do nas wchodzą
    m = g->inputs_count;
    for (int i = 0; i < m ; i++) {
        nand_t *inp_gate = g->inputs_nand[i];
        if (!inp_gate) {
        	continue;
        }
        vector *out_inp_gate = inp_gate->output_nands;
        for (int j = out_inp_gate->k; j >= 0; j--) {
            if (out_inp_gate->tab[j].nand == g) {
                g->inputs_nand[out_inp_gate->tab[j].input] = NULL;
                pop(out_inp_gate, j);
            }
        }
    }

    // Usuwanie bramki
    free(g->inputs_nand);
    free(g->inputs_bool);
    delete(g->output_nands);
    free(g);
}

	// Funkcja podłączająca wyjście bramki g_out do k-tego wejścia bramki g_in - Jeśli któraś z bramek g_out lub g_in 
	// jest NULLem lub jeśli k jest większe niż liczba wejść w bramce g_in, to ustawiamy errno na EINVAL. Następnie,
	// jeśli k-te wejście bramki g_in jest zajęte przez inną bramkę to odłączamy aktualną bramkę lub jeśli k-te 
	// wejście bramki g_in jest zajęte przez sygnał boolowski, to ustawiamy wartość w tablicy na NULL. Na koniec
	// podłączamy bramkę g_out w k-te miejsce w wejściu bramki g_in.
int nand_connect_nand(nand_t *g_out, nand_t *g_in, unsigned k) {
    if (g_out == NULL || g_in == NULL) {
        errno = EINVAL;
        return -1;
    }
    if (k >= g_in->inputs_count) {
        errno = EINVAL;
        return -1;
    }

	// Odłączanie starej bramki
    if (g_in->inputs_nand[k] != NULL) {
        nand_t *old = g_in->inputs_nand[k];

        for (int i = 0; i < old->output_nands->k; i++) {
            if (old->output_nands->tab[i].nand == g_in &&
                old->output_nands->tab[i].input == (int)k) {
                pop(old->output_nands, i);
                break;
            }
        }
    }

	// Odłączanie sygnału boolowskiego
    if (g_in->inputs_bool[k] != NULL) {
        g_in->inputs_bool[k] = NULL;
    }

	// Podłączanie nowej bramki
    g_in->inputs_nand[k] = g_out;
    push(g_out->output_nands, g_in, k);

    return 0;
}

	// Funkcja podłączająca sygnał boolowski s do k-tego wejścia bramki g - Jeśli s lub g jest NULLem lub jeśli k jest 
	// większe niż liczba wejść w bramce g, to ustawiamy errno na EINVAL. Natępnie jeśli k-te wejście bramki g jest 
	// zajęte przez inną bramkę to odłączamy aktualną bramkę. Na koniec podłączamy sygnał s na k-te wejście bramki g.
int nand_connect_signal(bool const *s, nand_t *g, unsigned k) {
    if (s == NULL || g == NULL) {
        errno = EINVAL;
        return -1;
    }
    if (k >= g->inputs_count) {
        errno = EINVAL;
        return -1;
    }

	// Odłączanie starej bramki
    if (g->inputs_nand[k] != NULL) {
        nand_t *old = g->inputs_nand[k];
        for (int i = 0; i < old->output_nands->k; i++) {
            if (old->output_nands->tab[i].nand == g && old->output_nands->tab[i].input == (int)k) {
                pop(old->output_nands, i);
                break;
            }
        }
    }
    g->inputs_nand[k] = NULL;
    
    // Podłączanie sygnału boolowskiego
    g->inputs_bool[k] = (bool *)s;
    return 0;
}

	// Funkcja wyznaczająca liczbę wejść bramek podłączonych do wyjścia danej bramki - Jeśli bramka g jest NULLem to
	// ustawiamy errno na EINVAL. W przeciwnym razie zwracamy liczbę wejść podłączonych bramek, czyli długość wektora
	// output_nands.
ssize_t nand_fan_out(nand_t const *g) {
    if (g == NULL) {
        errno = EINVAL;
        return -1;
    }

	// Wyznaczanie długości wektora outputs_nands
    if (g->output_nands == NULL) {
        return 0;
    }
    return g->output_nands->k;
}

	// Funkcja zwracająca wskaźnik do sygnału boolowskiego lub bramki podłączonej do k-tego wejścia bramki g - Jeśli bramka 
	// jest NULLem lub jeśli k jest większe niż liczba wejść w bramce g, to ustawiamy errno na EINVAL. Następnie, jeśli 
	// na k-tym wejściu był sygnał boolowski to go zwracamy lub jeśli była podłączona bramka to ją zwracamy. 
void *nand_input(nand_t const *g, unsigned k) {
    if (g == NULL || k >= g->inputs_count) {
        errno = EINVAL;
        return NULL;
    }
    
    // Zwracanie podłączonego sygnału
    if (g->inputs_bool[k] != NULL) {
        return g->inputs_bool[k];
    }

	// Zwracanie podłączonej bramki
    if (g->inputs_nand[k] != NULL) {
        return g->inputs_nand[k];
    }

    errno = 0;
    return NULL;
}

	// Funkcja zwracająca wskażnik na bramkę podłączoną do wyjścia bramki g
nand_t *nand_output(nand_t const *g, ssize_t k) {
    return g->output_nands->tab[k].nand;
}

	// Definicja funkcji pomocniczych potrzebnych do działania funkcji nand_evaluate - Funkcja DFS_cycle_exists sprawdza czy 
	// w spójnej składowej w której znajduje się bramka v nie ma cyklu. Funckja zero_DFS ustawia w bramkach wartość visited na 
	// wartość początkową. Funkcja evaluate wyznacza wyjściową wartość na bramce v oraz wyznacza długość ścieżki krytycznej 
	// danej bramki.
bool DFS_cycle_exists(nand_t *v, vector *visited_nand);
void zero_DFS(vector *visited_nand);
ssize_t evaluate(nand_t *v);

	// Funkcja wyznaczająca wartości sygnałów na wyjściach podanych bramek i obliczająca długość ścieżki krytycznej dla układu 
	// bramek - Jeśli mamy 0 bramek do rozpatrzenia lub któraś z tablic jest NULLem lub któraś z bramek w tablicy g jest NULLem
	// to ustawiamy errno na EINVAL. Jeśli znaleźliśmy cykl to nie da się przeprowadzić evaluacji i wówczas ustawiamy errno na 
	// ECANCELED. Dla każdej bramki v z g robimy evaluate. Jeśli bramka nie ma wejść to sygnał jest false. W wektorze
	// visited_nand będziemy umieszczali bramki które odwiedzaliśmy w czasie przechodzenia po grafie, którą po przejściu DFS-a 
	// będziemy zerowali. Na koniec wyznaczamy długość ścieżki krytycznej układu, czyli porównujemy długość ścieżki krytycznej
	// bramki v z aktualnie najdłuższą ścieżką krytyczną układu.
ssize_t nand_evaluate(nand_t **g, bool *s, size_t m) {
    if (m == 0) {
        errno = EINVAL;
        return -1;
    }
    if (g == NULL || s == NULL) {
        errno = EINVAL;
        return -1;
    }

    for (size_t i = 0; i < m; i++) {
        if (g[i] == NULL) {
            errno = EINVAL;
            return -1;
        }
    }

    int max_critical_path = 0;

    // Dla każdej bramki z g robimy evaluate.
    for (size_t i = 0; i < m; i++) {
        nand_t *v = g[i];        
        if (v->inputs_count == 0) {
            s[i] = 0;
        } else {
            vector *visited_nand = new_vector();
            if (DFS_cycle_exists(v, visited_nand) == 1) {
                errno = ECANCELED;
                zero_DFS(visited_nand);
                return -1;
            }
            zero_DFS(visited_nand);
            ssize_t critical_path_length = evaluate(v);
            if (critical_path_length > max_critical_path) {
                max_critical_path = critical_path_length;
            }
            s[i] = v->output;
        }
    }
    
    return max_critical_path;
}

	// Funkcja wyznaczająca wyjściową wartość na bramce v oraz wyznaczająca długość ścieżki krytycznej danej bramki - 
	// Jeśli bramka nie ma wejść to długość ścieżki krytycznej wynosi 0. Następnie dla każdej bramki z wejścia 
	// wyznaczamy długość jej ścieżki krytycznej sprawdzając czy nie jest ona przypadkiem większa niż wyznaczona  
	// do tej pory długość ścieżki krytycznej bramki v, czyli max_path. Wyznaczamy wartość wyjściową na bramce v. Jest
	// to negacja koniunkcji wartości sygnałów na wejściu bramki v. 
ssize_t evaluate(nand_t *v) {
    ssize_t max_path = 0;
    bool new_output = 1;
    
    // Bramka v nie ma wejść. 
    if (v->inputs_count == 0) {
    	return 0;
    }
    	
	// Wyznaczanie długości ścieżki krytycznej oraz wyjściowej wartości sygnału na bramce
    for (unsigned int i = 0; i < v->inputs_count; i++) {
        if (v->inputs_nand[i] != NULL) {
            ssize_t path = evaluate(v->inputs_nand[i]);
            if (path > max_path) {
                max_path = path;
            }
            new_output = new_output & v->inputs_nand[i]->output;
        } else {
            new_output = new_output & *v->inputs_bool[i];
        }
    }
    v->output = !new_output;
    return max_path + 1;
}

	// Funkcja sprawdzająca czy w spójnej składowej w której znajduje się bramka v nie ma cyklu - Jeśli bramka v jest
	// NULLem to ustawiamy errno na ECANCLED. Następnie uruchamiamy DFS-a. Bramki traktujemy jak wierzchołki, natomiast
	// połączenia traktujemy jak krawędzie skierowane. Jeśli wróciliśmy do wierzchołka zanim zakończyliśmy przechodzenie
	// jego sąsiadów to znaleźliśmy cykl. Jeśli natrafiliśmy na wierzchołek już odwiedzony, to zawracamy. W przeciwnym 
	// przypadku rozpatrywany wierzchołek odwiedzamy po raz pierwszy. Ustawiamy wartość visited na 1, czyli że jesteśmy
	// w trakcie odwiedzania go. Wkładamy wierzchołek na wektor wierzchołków do wyzerowania visited_nand. Następnie 
	// dla każdego wejścia bramki v, jeśli podłączony jest sygnał boolowski to kontunuujemy, w przeciwnym razie 
	// rekurencyjnie uruchamiamy DFS-a dla bramkik podłączonej do danego wejścia. Na koniec po odwiedzeniu wszystkich 
	// sąsiadów oznaczamy bramkę v jako odwiedzoną. 
bool DFS_cycle_exists(nand_t *v, vector *visited_nand) {
    if (v == NULL) {
        errno = ECANCELED;
        return -1;
    }

	// Wierzchołek jest już odwiedzony.
    if (v->visited == 2) {
        return 0;
    }

	// Znalezienie cyklu
    if (v->visited == 1) {

        return 1;
    }

	// Wierzchołek jest odwiedzany po raz pierwszy. 
    v->visited = 1;
    push(visited_nand, v, 0);
    for (unsigned int i = 0; i < v->inputs_count; i++) {
        if (v->inputs_bool[i] != NULL) {
            continue;
        }
        if (DFS_cycle_exists(v->inputs_nand[i], visited_nand) == 1) {
            return 1;
        }
    }
    v->visited = 2;

    return 0;
}

	// Funkcja przywracająca wartości początkowe parametru visited w bramkach znajdujących się w wektorze visited_nand
void zero_DFS(vector *visited_nand) {
    int k = visited_nand->k;

	// Przywracanie wartości początkowej
    for (int i = 0; i < k; i++) {
        nand_t *v = visited_nand->tab[i].nand;
        v->visited = 0;
    }

	// Usuwanie wektora visited_nand
    delete(visited_nand);
}
