%define X_0 rdi                                            ; Początek tablicy X
%define X_n rdi + 8 * rsi - 8                              ; Koniec tablicy X 

global mdiv

mdiv:
            ; Początkowe wartości rejestrów.
        ; rdi - dzielna (wskaźnik na tablicę x)
        ; rsi - rozmiar tablicy x
        ; rdx - dzielnik

            ; Poczatkowe przyporzadkowanie rejestrow typu scratch.
    mov r8, rdx                                            ; r8 - dzielnik y.
    mov r9, rdx                                            ; r9 - znak dzielnika.
    mov r10, [X_n]                                         ; r10 - znak dzielnej.

            ; Sprawdzamy znak ostatniego elementu tabeli X. 
    mov rax, [X_n] 
    test rax, rax      
    jns divide                                             ; Dzielnik jest dodatni to możemy dzielić. 

            ; Negujemy dzielną - Rejestr rcx (początkowo równy n) będzie iteratorem pętli, zaś rejestr
            ; rax (początkowo równy 0) będzie i-tym elementem tablicy X, którego negujemy. Ustawiamy
            ; flagę przeniesienia (CF - Carry Flag). Będzie ona używana podczas operacji dodawania
            ; z przeniesieniem, aby uwzględnić zmienione bity (przeniesienia) po operacji NOT. Następnie
            ; dodajemy 0 do znegowanej wartości, uwzględniając flagę przeniesienia (CF), która została 
            ; ustawiona przez `stc`.
    mov  rcx, rsi    
    xor  rax, rax              
    stc                                                    ; Ustawiamy flagę przeniesienia DF.
divisor_negative:
    not  qword[X_0 + 8 * rax]                              ; Negujemy wszystkie bity.
    adc  qword[X_0 + 8 * rax], 0 
    inc  rax                           
    loop divisor_negative    
    
        ; Sprawdzamy czy nie ma przypadku MININT/(-1) - Jeśli po negacji liczby ujemnej mamy liczbę ujemną to mamy MININT. 
    mov rax, [X_n]
    test rax, rax                                          ; Sprawdzamy czy licznik to MININT.                              
    jns divide
    cmp r8, -1                                             ; Sprawdzamu czy mianownik to -1.
    jne divide 
    xor rax, rax
    div rax                                                ; Operacja dzielenia przez 0.
    
        ; Rozpoczynamy dzielenie.
divide:
    xor rdx, rdx                                           ; Początkowa wartość reszty to 0.
    lea rcx, [X_n]                                         ; Wskaznik na koniec tablicy X.
    test r8, r8                                            ; Zamieniamy dzielnik na wartość bezwzględną.
    jns divide_loop
    neg r8

            ; Pętla dzieląca poszczególne komórki - Dzielenie 128b liczby (rdx:rax = reszta:kolejna_komorka) przez 64b 
            ; liczbe w wyniku otrzymujemy 64b iloraz (rax) i reszte (rdx).
divide_loop:
    mov rax, [rcx]                                         ; W rax umieszczamy kolejną komórkę tablicy X.
    div r8                                                 ; Dzielimy rdx:rax przez r8 -> w rax mamy iloraz (64b) w rdx mam resztę.
    mov [rcx], rax                                         ; W danej komórce tablicy X umieszczamy iloraz.
    cmp rcx, X_0                                           ; Sprawdzamy czy nie doszliśmy do końca tablicy.
    je result                                              ; Jeśli tak to zakańczamy pętle.
    sub rcx, 8                                             ; Przesuwamy iterator o jedną wartość.                                            
    jmp divide_loop
    
result:
    xor  r9, r10                                           ; Sprawdzamy, czy dzielna i dzielnik mają różne znaki.
    jns  exit                                              ; Jeśli nie to negujemy wynik (identycznie jak negowanie dzielnej).
    mov  rcx, rsi    
    xor  rax, rax              
    stc             
result_negative:
    not  qword[X_0 + 8 * rax]       
    adc  qword[X_0 + 8 * rax], 0 
    inc  rax                           
    loop result_negative    

            ; Wyjscie z funkcji.
exit:
    test r10, r10                                          ; Jeśli dzielna była ujemna to negujemy resztę. 
    jns return
    neg rdx
    
        ; Zwracamy resztę. 
return:
    mov rax, rdx                                                
    ret
    
