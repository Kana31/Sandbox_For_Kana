-- Um chatbot simples em lua que usa uma rede neural recorrente para gerar respostas
-- Baseado em https://github.com/oxford-cs-ml-2015/practical6

require 'torch'
require 'nn'
require 'nngraph'
require 'optim'
require 'lfs'
require 'util.misc'

-- Carregar os dados de treinamento
local data_dir = 'data/chatbot' -- Diretório onde estão os arquivos de texto
local vocab_file = path.join(data_dir, 'vocab.t7') -- Arquivo com o vocabulário
local tensor_file = path.join(data_dir, 'data.t7') -- Arquivo com os tensores de entrada e saída
local vocab, data
if not (path.exists(vocab_file) or path.exists(tensor_file)) then
  print('Processando os dados de texto...')
  vocab, data = preprocess(data_dir) -- Função para processar os arquivos de texto e criar o vocabulário e os tensores
  torch.save(vocab_file, vocab)
  torch.save(tensor_file, data)
else
  print('Carregando os dados pré-processados...')
  vocab = torch.load(vocab_file)
  data = torch.load(tensor_file)
end

-- Criar o modelo da rede neural recorrente
local model = {}
model.criterion = nn.ClassNLLCriterion() -- Critério de perda
model.lstm = LSTM.lstm(vocab.size, opt.rnn_size, opt.num_layers, opt.dropout) -- Função para criar a camada LSTM
model.softmax = nn.Sequential():add(nn.Linear(opt.rnn_size, vocab.size)):add(nn.LogSoftMax()) -- Camada de saída softmax
model.params, model.grad_params = model_utils.combine_all_parameters(model.lstm, model.softmax) -- Parâmetros e gradientes do modelo
model.clones = {} -- Clones do modelo para cada passo do tempo
for name, proto in pairs(model) do
  if name ~= 'params' and name ~= 'grad_params' then
    print('Clonando ' .. name)
    model.clones[name] = model_utils.clone_many_times(proto, opt.seq_length, not proto.parameters)
  end
end

-- Inicializar o estado da rede neural
local init_state = {}
for L=1,opt.num_layers do
  local h_init = torch.zeros(opt.batch_size, opt.rnn_size)
  if opt.gpuid >=0 then h_init = h_init:cuda() end
  table.insert(init_state, h_init:clone())
  table.insert(init_state, h_init:clone())
end

-- Função para avaliar a perda e o gradiente em um mini-lote
local function feval(x)
  if x ~= model.params then
    model.params:copy(x)
  end
  model.grad_params:zero()

  ------------------ obter mini-lote -------------------
  local x, y = data:next_batch(opt.batch_size, opt.seq_length) -- Entrada e saída do mini-lote
  if opt.gpuid >= 0 then -- Transferir para GPU se necessário
    x = x:float():cuda()
    y = y:float():cuda()
  end

  ------------------- forward pass -------------------
  local rnn_state = {[0] = init_state}
  local predictions = {}           -- softmax outputs
  local loss = 0
  for t=1,opt.seq_length do
    model.clones.lstm[t]:training() -- Garantir que estamos no modo de treinamento 
    local lst = model.clones.lstm[t]:forward{x[t], unpack(rnn_state[t-1])}
    rnn_state[t] = {}
    for i=1,#init_state do table.insert(rnn_state[t], lst[i]) end -- Extrair o estado oculto e a célula 
    predictions[t] = model.clones.softmax[t]:forward(lst[#lst]) -- Obter a previsão softmax 
    loss = loss + model.criterion:forward(predictions[t], y[t]) -- Calcular a perda 
  end
  
  loss = loss / opt.seq_length

  ------------------ backward pass -------------------
  local drnn_state = {[opt.seq_length] = clone_list(init_state, true)} -- true significa zero os tensores 
  for t=opt.seq_length,1,-1 do
    local doutput_t = model.criterion:backward(predictions[t], y[t])
    local dsoftmax_t = model.clones.softmax[t]:backward(rnn_state[t][#rnn_state[t]], doutput_t)
    table.insert(drnn_state[t], dsoftmax_t)
    local dlst = model.clones.lstm[t]:backward({x[t], unpack(rnn_state[t-1])}, drnn_state[t])
    drnn_state[t-1] = {}
    for k,v in pairs(dlst) do
      if k > 1 then -- k == 1 é a entrada x, que não precisamos 
        drnn_state[t-1][k-1] = v
      end
    end
  end

  ------------------ gradient clipping -------------------
  local grad_norm = model.grad_params:norm()
  if grad_norm > opt.max_grad_norm then
    local shrink_factor = opt.max_grad_norm / grad_norm
    model.grad_params:mul(shrink_factor)
  end

  return loss, model.grad_params
end

-- Função para gerar uma resposta a partir de uma entrada
local function generate(input)
  local words = split(input, ' ') -- Dividir a entrada em palavras 
  local x = torch.Tensor(#words) -- Tensor de entrada 
  for i, word in ipairs(words) do
    if vocab.index[word] then -- Verificar se a palavra está no vocabulário 
      x[i] = vocab.index[word]
    else -- Caso contrário, usar o token desconhecido 
      x[i] = vocab.index['<unk>']
    end
  end
  if opt.gpuid >= 0 then x = x:float():cuda() end -- Transferir para GPU se necessário 

  local rnn_state = init_state -- Estado inicial da rede neural 
  local output = {} -- Saída gerada 
  local eos = false -- Indicador de fim de sentença 
  local t = 0 -- Contador de passos de tempo 
  while not eos and t < opt.max_length do -- Repetir até encontrar o token <eos> ou atingir o comprimento máximo 
    t = t + 1
    model.lstm:evaluate() -- Garantir que estamos no modo de avaliação 
    local lst = model.lstm:forward{x[t], unpack(rnn_state)} -- Fazer um passo à frente na rede neural 
    rnn_state = {}
    for i=1,#init_state do table.insert(rnn_state, lst[i]) end -- Extrair o estado oculto e a célula 
    local prediction = model.softmax:forward(lst[#lst]) -- Obter a previsão softmax 
    local _, max_index = prediction:max(2) -- Obter o índice do valor máximo 
    local word_index = max_index[1][1] -- Obter o índice da palavra 
    local word = vocab.word[word_index] -- Obter a palavra correspondente 
    table.insert(output, word) -- Adicionar a palavra à saída 
    if word == '<eos>' then eos = true end -- Verificar se é o fim da sentença 
  end

  return table.concat(output, ' ') -- Retornar a saída como uma string 
end

-- Treinar o modelo usando o algoritmo RMSprop
local optim_state = {learningRate = opt.learning_rate, alpha = opt.decay_rate}
local iterations = opt.max_epochs * data.nbatches
local losses = {}
local timer = torch.Timer()
local epoch = 0
for i = 1, iterations do
  epoch = i / data.nbatches

  local _, loss = optim.rmsprop(feval, model.params, optim_state)
  
  losses[i] = loss[1]

  if i % opt.print_every == 0 then
    print(string.format("%d/%d (epoch %.3f), train_loss = %6.8f, grad/param norm = %6.4e, time/batch = %.2fs", i, iterations, epoch, loss[1], model.grad_params:norm() / model.params:norm(), timer:time().real))
    timer:reset()
  end
  
  if i % opt.eval_every == 0 then
    print('\nGerando algumas respostas...')
    local samples = {'oi', 'qual é o seu nome?', 'você gosta de lua?', 'me conte uma piada'}
    for _, sample in ipairs(samples) do
      print('Entrada: ' .. sample)
      print('Saída: ' .. generate(sample))
      print('')
    end
    print('Continuando o treinamento...')
  end
  
end

print('Treinamento concluído!')
