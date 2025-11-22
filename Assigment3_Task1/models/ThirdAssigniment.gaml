/**
* Name: ThirdAssignmentC
* Author: agata Mazzani, Daniele Priola, Jacopo Veronese
* Description: N Qeens problem
*/

model NQueens


global {

    int N <- 16;
    list<Queen> queens <- [];
    bool solution_found <- false;
    bool no_solution <- false;
    float cell_size <- 1.0;

    init {
        create Queen number: N returns: created_queens;
        queens <- created_queens;
        loop i from: 0 to: N - 1 {
            Queen q <- queens[i];
            q.index <- i;
            q.my_col <- i;
            q.location <- {-5, -5};

            if (i > 0) { q.predecessor <- queens[i - 1]; }
            if (i < N - 1) { q.successor <- queens[i + 1]; }
        }
        write "N = " + N;
        write "Inizio: Mando messaggio alla Regina 0";
        ask queens[0] {
            do start_conversation to: [self] protocol: 'fipa-propose' performative: 'propose' contents: ["start", []];
        }
    }
}


species Queen skills: [fipa] {
    int index;
    int my_col;
    int my_row <- -1;
    Queen predecessor;
    Queen successor;
    list<int> history_received <- [];
    bool processing <- false;  // Evita elaborazioni multiple

    bool is_safe(int check_row, list<int> prev_positions) {
        if (empty(prev_positions)) {
            return true;
        }
        int i <- 0;
        loop other_row over: prev_positions {
            int other_col <- i;
            if (check_row = other_row) { return false; }
            if (abs(check_row - other_row) = abs(my_col - other_col)) { return false; }
            i <- i + 1;
        }
        return true;
    }

    action update_position {
        location <- {(my_col + 0.5) * cell_size, (my_row + 0.5) * cell_size};
    }

    action find_and_communicate {
        if (solution_found or no_solution) { return; }
        int start_row <- my_row + 1;

        if (start_row >= N) {
            my_row <- -1;
            location <- {-5, -5};
       
            if (predecessor != nil) {
                //write "Regina " + index + " ha esaurito le righe (start=" + start_row + "). BACKTRACK a Regina " + (index - 1);
                do start_conversation to: [predecessor] protocol: 'fipa-propose' performative: 'propose' contents: ["backtrack", []];
            } else {
                write "*** IMPOSSIBILE TROVARE SOLUZIONE ***";
                no_solution <- true;
            }
            return;
        }

        bool found <- false;
        
        loop r from: start_row to: N - 1 {
            if (is_safe(r, history_received)) {
                my_row <- r;
                found <- true;
                do update_position;

                list<int> new_history <- copy(history_received);
                new_history <- new_history + [my_row];

                if (successor != nil) {
                    //write "Regina " + index + " si piazza a riga " + my_row + ", colonna " + my_col + " | Config: " + new_history;
                    do start_conversation to: [successor] protocol: 'fipa-propose' performative: 'propose' contents: ["next", new_history];
                } else {
                    solution_found <- true;
                    write "*** SOLUZIONE TROVATA! Configurazione: " + new_history + " ***";
                }
                return;
            }
        }
        my_row <- -1;
        location <- {-5, -5};

        if (predecessor != nil) {
            //write "Regina " + index + " bloccata (nessuna riga safe da " + start_row + " a " + (N-1) + "). BACKTRACK a Regina " + (index - 1);
            do start_conversation to: [predecessor] protocol: 'fipa-propose' performative: 'propose' contents: ["backtrack", []];
        } else {
            write "*** IMPOSSIBILE TROVARE SOLUZIONE ***";
            no_solution <- true;
        }
    }

    reflex receive_messages when: !empty(proposes) and !solution_found and !no_solution {
        message m <- proposes[0];
        loop msg over: proposes {
        }
        list c <- m.contents;
        string msg_type <- c[0];
        if (msg_type = "start" or msg_type = "next") {
            history_received <- c[1];
            my_row <- -1;  
            //write "Regina " + index + " riceve '" + msg_type + "' con history: " + history_received;
            do find_and_communicate;
        }

        if (msg_type = "backtrack") {
            //write "Regina " + index + " riceve BACKTRACK, riprova da riga " + (my_row + 1);
            do find_and_communicate;
        }
    }

    aspect default {
        draw circle(cell_size * 0.4) color: #red border: #black;
    }
}

experiment NQueensExperiment type: gui {
    parameter "Numero di Regine" var: N min: 4 max: 20;
    output {
        display board type: 2d axes: false antialias: true {
            graphics "chessboard" {
                loop i from: 0 to: N - 1 {
                    loop j from: 0 to: N - 1 {
                        rgb col <- ((i + j) mod 2 = 0) ? #white : #gray;
                        draw rectangle(cell_size, cell_size) at: {(i + 0.5) * cell_size, (j + 0.5) * cell_size} color: col;
                    }
                }
            }
            species Queen aspect: default;
        }
    }
}
