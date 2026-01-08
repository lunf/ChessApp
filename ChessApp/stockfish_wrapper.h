//
//  stockfish_wrapper.h
//  ChessApp
//
//  Created by cuong.nguyenhat on 16/12/25.
//

#ifndef STOCKFISH_WRAPPER_H
#define STOCKFISH_WRAPPER_H

#ifdef __cplusplus
extern "C" {
#endif

void engine_init(void);
void sf_init(void);
void sf_send(const char* command);
const char* sf_read(void);
void sf_shutdown(void);

#ifdef __cplusplus
}
#endif

#endif

