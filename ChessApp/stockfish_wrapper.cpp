//
//  stockfish_wrapper.c
//  ChessApp
//
//  Created by cuong.nguyenhat on 16/12/25.
//

#include "stockfish_wrapper.h"

#include <atomic>
#include <mutex>
#include <queue>
#include <string>
#include <thread>

#include "attacks.h"
#include "bitboard.h"
#include "engine.h"
#include "misc.h"
#include "position.h"
#include "tune.h"
#include "uci.h"

using namespace Stockfish;

/* =========================
   Global state
   ========================= */

static std::unique_ptr<UCIEngine> uci;
static std::thread engineThread;
static std::atomic<bool> running{false};

/* =========================
   INPUT (Swift -> Stockfish)
   ========================= */

static std::mutex inputMutex;
static std::condition_variable inputCV;
static std::queue<std::string> inputQueue;

class InputBuf : public std::streambuf {
protected:
    int underflow() override {
        std::unique_lock<std::mutex> lock(inputMutex);
        inputCV.wait(lock, [] { return !inputQueue.empty() || !running; });

        if (!running) return EOF;

        current = inputQueue.front();
        inputQueue.pop();
        setg(current.data(), current.data(),
             current.data() + current.size());

        return traits_type::to_int_type(*gptr());
    }

private:
    std::string current;
};

static InputBuf inputBuf;
static std::streambuf* oldCin = nullptr;

/* =========================
   OUTPUT (Stockfish -> Swift)
   ========================= */

static std::mutex outputMutex;
static std::queue<std::string> outputQueue;

class OutputBuf : public std::streambuf {
protected:
    int overflow(int c) override {
        if (c == EOF) return c;

        if (c == '\n') {
            std::lock_guard<std::mutex> lock(outputMutex);
            outputQueue.push(buffer);
            buffer.clear();
        } else {
            buffer += char(c);
        }
        return c;
    }

private:
    std::string buffer;
};

static OutputBuf outputBuf;
static std::streambuf* oldCout = nullptr;

/* =========================
   API
   ========================= */

void sf_init() {
    if (running) return;

    {
        std::lock_guard<std::mutex> lock(inputMutex);
        std::queue<std::string> empty;
        std::swap(inputQueue, empty);
    }

    {
        std::lock_guard<std::mutex> lock(outputMutex);
        std::queue<std::string> empty;
        std::swap(outputQueue, empty);
    }

    running = true;

    oldCin  = std::cin.rdbuf(&inputBuf);
    oldCout = std::cout.rdbuf(&outputBuf);

    engineThread = std::thread([] {
        int argc = 1;
        char* argv[] = { (char*)"stockfish" };

        Bitboards::init();
        Attacks::init();
        Position::init();

        uci = std::make_unique<UCIEngine>(argc, argv);
        Tune::init(uci->engine_options());

        uci->loop();
    });
}

void sf_send(const char* command) {
    if (!running) return;

    {
        std::lock_guard<std::mutex> lock(inputMutex);
        inputQueue.push(std::string(command) + "\n");
    }
    inputCV.notify_one();
}

const char* sf_read() {
    static std::string line;

    std::lock_guard<std::mutex> lock(outputMutex);
    if (outputQueue.empty()) return nullptr;

    line = outputQueue.front();
    outputQueue.pop();
    return line.c_str();
}

bool sf_is_running() {
    return running;
}

void sf_shutdown() {
    if (!running) return;

    sf_send("quit");
    inputCV.notify_all();

    if (engineThread.joinable())
        engineThread.join();

    running = false;

    std::cin.rdbuf(oldCin);
    std::cout.rdbuf(oldCout);
}
