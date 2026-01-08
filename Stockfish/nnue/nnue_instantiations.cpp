//
//  nnue_instantiations.cpp
//  ChessApp
//
//  Created by cuong.nguyenhat on 15/12/25.
//

#include "network.h"
#include "nnue_architecture.h"
#include "nnue_feature_transformer.h"

namespace Stockfish::Eval::NNUE {

// Force instantiation of the network used by Stockfish
template class Network<
    NetworkArchitecture<1024, 15, 32>,
    FeatureTransformer<1024>
>;
}
