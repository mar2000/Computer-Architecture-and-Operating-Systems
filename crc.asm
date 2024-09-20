%macro SYS_OPEN 0
    mov rax, 2
%endmacro

%macro SYS_WRITE 0
    mov rax, 1
%endmacro

%macro SYS_CLOSE 0
    mov rax, 3
%endmacro

%macro SYS_READ 0
    xor rax, rax    
%endmacro

%macro SYS_EXIT 0
    mov rax, 60
%endmacro

%macro SYS_LSEEK 0
    mov rax, 8
%endmacro

%macro SEEK_SET 0
    mov rdx, 0
%endmacro

%macro SEEK_CUR 0
    mov rdx, 1
%endmacro

%macro SEEK_END 0
    mov rdx, 2
%endmacro

section .bss

    file_id: resq 1                                        ; Deklaruje zmienna na identyfikator pliku wejsciowego.
    crc_table: resq 256                                    ; Tablica wyszukiwania (lookup).
    buffer: resb 65542                                     ; Bufor do odczytu o długości 65542 bajtów, aby mógł pomieścić jeden blok danych.

        ; Dodatkowe parametry trzymane w rejestrach.   
    ; r8 - wielomian
    ; r9 - wielkosc wielomianu

section .text
    global _start
_start:

        ; Wczytywanie parametrów.
    mov cl, [rsp]                                          ; Wczytaj pierwszy argument z stosu do rejestru rcx.
    cmp cl, 3                                              ; Porównaj liczbę wczytanych parametrów z 3 (nazwa pliku wykonywalnego i dwa argumenty).
    jne exit_error                                         ; Jeśli rcx nie jest równe 3, przejdź do exit_error.
    xor r8, r8
    xor r9, r9
    
         ; Wczytywanie pliku i sprawdzanie poprawnosci.
    SYS_OPEN                                               ; Wywołaj systemowe otwarcie pliku.
    mov rdi, [rsp + 16]                                    ; Wczytaj drugi argument z stosu do rejestru rdi.
    xor rsi, rsi                                           
    syscall
    test rax, rax
    js exit_error
    mov [file_id], rax
    
            ; Wczytywanie wielomianu i sprawdzanie poprawnosci.
    mov rsi, [rsp + 24]                                    ; Wczytuje trzeci parametr do rejestru rsi.
check_crc:                                                 ; Liczymy długość wielomianu i sprawdzamy poprawność.
    cmp byte [rsi + r9], 0                                 ; Sprawdz, czy dotarliśmy do konca stringa.
    je read_done
    shl r8, 1
    cmp byte [rsi + r9], '0'                               ; Jeśli znaleziono '0', przejdź do sprawdzenia następnego znaku.
    je valid_digit                                         
    or r8, 1
    cmp byte [rsi + r9], '1'                               ; Jeśli znaleziono '1', przejdź do sprawdzenia następnego znaku.
    jne close_file_exit_error                              ; Jeśli znaleziono inny znak niż '0' lub '1', wyjdź z błędem.
valid_digit:
    inc r9 
    cmp r9, 65                                             ; Sprawdź, czy przekroczono maksymalną długość 64.
    jge close_file_exit_error                              ; Jeśli tak, wyjdź z błędem.
    jmp check_crc 
read_done:
    test r9, r9                                            ; Jeśli długość wielomianu jest zerowa to wyjdź z błędem.
    je close_file_exit_error    
    mov rcx, 64              
    sub rcx, r9                                            ; Oblicz, ile bitów brakuje do 64.
    shl r8, cl                                             ; Uzupełnij wielomian zerami. 
   
        ; Stworzenie tabeli wyszukiwania (lookup), która umożliwi przetwarzanie strumienia wejściowego bajt po bajcie, a nie bit po bicie [1]. 
    mov rax, 255                                           ; Ustawiamy początkową wartość rax na 255 (pełna tabela dla każdego bajtu).
lookup_loop:
    mov rbx, rax                                
    shl rbx, 56                                            
    mov cl, 8                                              ; Liczymy CRC dla 8 bitów (po jednym bajcie).
byte_crc:
    shl rbx, 1                                  
    jnc skip                                               ; Jeśli nie było przeniesienia, pomijamy XOR.
    xor rbx, r8                                            ; XOR z wielomianem r8.
skip:
    loop byte_crc                     
    mov [crc_table + rax * 8], rbx                         ; Zapisujemy wynik do tablicy.
    dec rax                                      
    jns lookup_loop                                        ; Powtarzamy dla każdego bajtu, dopóki rax >= 0.

        ; Funkcja wczytujaca paczki danych do bufora i odpalajaca wyznaczanie CRC.
    xor rcx, rcx                                           ; rcx - wartosc skoku (dodatnia jesli w prawo i ujemna gdy w lewo).
    xor r8, r8                                             ; r8 - tu będziemy zapisywać wynikowy wielomian.
buffor_loop: 
    SYS_LSEEK
    mov rdi, [file_id]
    mov rsi, rcx
    SEEK_CUR
    syscall
    test rax, rax
    js close_file_exit_error
    SYS_READ                                               ; Ładowanie danych do bufora.
    mov rdi, [file_id]       
    mov rsi, buffer          
    mov rdx, 65542            
    syscall
    cmp rax, 0                                             ; Jeśli nie udało się załadować danych, wyjdź z błędem. 
    jle close_file_exit_error 
    lea rsi, [buffer]                                      ; rsi - wskaźnik na bufor.
    mov bx, word[rsi]                                      ; Wczytanie dwóch bajtów do rejestru bx.
    movzx rbx, bx                                          ; Rozszerzenie wartosci z rejestru bx do rejestru rbx.
    add rsi, 2   
    mov rcx, rbx                                           ; rcx - liczba bajtów do przetworzenia.
    mov rdi, rbx
    sub rax, 6
    sub rax, rbx                                           ; rax - nadmiarowe przesunięcie (spowodowane wczytywaniem stałej liczby bajtów).
    xor rdx, rdx                                           ; rdx - iterator po pętli crc_loop.
crc_loop:                                                  ; Funkcja wyliczająca crc -  (rsi to wskaźnik na początek danych,  rcx to rozmiar danych).
    test rcx, rcx                                          ; Sprawdamy, czy są jeszcze bajty do przetworzenia
    jz done_crc                                            ; Jeśli nie, zakończ obliczanie
    mov bl, [rsi + rdx]
    shl rbx, 56
    xor rbx, r8
    shr rbx, 56
    shl r8, 8
    mov rbx, [crc_table + 8 * rbx]
    xor r8, rbx
    inc rdx
    dec rcx
    jmp crc_loop
done_crc:    
    add rsi, rdi                                           ; Dodanie długości danych.
    mov ebx, dword[rsi]                                    ; Wczytanie czterech bajtów do rejestru ebx.
    movsx rbx, ebx                                         ; Rozszerzenie wartości z rejestru ebx do rejestru rbx.
    mov rcx, rbx                                           ; rcx - długość skoku. 
    sub rcx, rax                                           ; rcx - faktyczny skok uwzględniający dodatkowe przesunięcie.
    add rbx, 6
    add rbx, rdi
    jnz buffor_loop                                        ; Jeśli rbx + rdi + 6 = 0 to mamy koniec pliku.
    jmp print_crc

            ; Wypisywanie wyliczonego crc ktore jest w r8. 
print_crc:
    mov rcx, 64              
    sub rcx, r9                                            ; Oblicz, ile bitów brakuje do 64.
    shr r8, cl
    mov rdx, r8
    mov rdi, buffer                                        ; rdi - iterator po buforze.      
    add rdi, 64         
    mov rbx, r9                                            ; rbx - iterator pętli print_crc_loop.        
print_crc_loop:                                            ; Wypisywanie wielomianu. 
    dec rdi
    test rdx, 1
    jz print_crc_zero
    mov byte [rdi], '1'
    jmp print_crc_next
print_crc_zero:
    mov byte [rdi], '0'
print_crc_next:
    shr rdx, 1
    dec rbx
    jnz print_crc_loop                                     ; Jeśli skończyła się pętla to wypisz buffor.
    SYS_WRITE
    mov rsi, rdi     
    mov rdx, r9         
    mov rdi, 1          
    syscall
    cmp rax, 0
    jl close_file_exit_error
    SYS_WRITE    
    mov byte [rsi], 0x0a                                   ; Wypisywanie znaku nowej lini.   
    mov rdx, 1     
    mov rdi, 1       
    syscall
    cmp rax, 0
    jl close_file_exit_error  
    jmp close_file_exit
    
        ; Wyjścia w różnych przypadkach.
close_file_exit_error:
    SYS_CLOSE            
    mov rdi, [file_id]
    syscall 
exit_error:
    SYS_EXIT            
    mov rdi, 1                                        
    syscall                 
close_file_exit:
    SYS_CLOSE
    mov rdi, [file_id]
    syscall
    cmp rax, 0
    jne exit_error
    SYS_EXIT            
    mov rdi, 0                                             
    syscall  
