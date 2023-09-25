

-- Importar bibliotecas necessárias
local http = require("socket.http")
local ltn12 = require("ltn12")
local json = require("json")

-- Definir uma função para baixar um arquivo da internet
local function download(url, filename)
  local file = io.open(filename, "wb")
  local response, status, headers = http.request{
    url = url,
    sink = ltn12.sink.file(file)
  }
  file:close()
  return response, status, headers
end

-- Definir uma função para extrair o URL do vídeo de uma página web
local function extract_video_url(page_url)
  local video_url = nil
  local response, status, headers = http.request(page_url)
  if status == 200 then -- se a página foi carregada com sucesso
    if page_url:match("youtube.com") then -- se é um vídeo do YouTube
      -- procurar pelo URL do vídeo no código-fonte da página
      video_url = response:match('"url":"(.-)"')
      if video_url then -- se encontrou o URL do vídeo
        -- decodificar os caracteres especiais no URL
        video_url = video_url:gsub("\\u0026", "&")
        video_url = video_url:gsub("\\", "")
      end
    elseif page_url:match("pinterest.com") then -- se é um vídeo do Pinterest
      -- procurar pelo URL do vídeo no código-fonte da página
      video_url = response:match('"video_url":"(.-)"')
      if video_url then -- se encontrou o URL do vídeo
        -- decodificar os caracteres especiais no URL
        video_url = video_url:gsub("\\u002F", "/")
        video_url = video_url:gsub("\\", "")
      end
    elseif page_url:match("facebook.com") then -- se é um vídeo do Facebook
      -- procurar pelo URL do vídeo no código-fonte da página
      video_url = response:match('"hd_src":"(.-)"')
      if not video_url then -- se não encontrou o URL do vídeo em alta definição
        -- procurar pelo URL do vídeo em baixa definição
        video_url = response:match('"sd_src":"(.-)"')
      end
      if video_url then -- se encontrou o URL do vídeo
        -- decodificar os caracteres especiais no URL
        video_url = video_url:gsub("\\u0025", "%")
        video_url = video_url:gsub("\\u0026", "&")
        video_url = video_url:gsub("\\u003F", "?")
        video_url = video_url:gsub("\\u003D", "=")
        video_url = video_url:gsub("\\u002B", "+")
        video_url = video_url:gsub("\\u002D", "-")
        video_url = video_url:gsub("\\u002E", ".")
        video_url = video_url:gsub("\\u005F", "_")
        video_url = video_url:gsub("\\u002F", "/")
        video_url = video_url:gsub("\\", "")
      end
    else -- se não é um vídeo suportado
      print("Desculpe, este tipo de vídeo não é suportado.")
    end
  else -- se a página não foi carregada com sucesso
    print("Desculpe, não foi possível carregar a página.")
  end
  return video_url 
end

-- Definir uma função para reproduzir um arquivo de vídeo localmente
local function play_video(filename)
  local command = "vlc " .. filename -- usar o VLC como player de vídeo padrão
  os.execute(command) -- executar o comando no sistema operacional
end

-- Pedir ao usuário para digitar o URL da página que contém o vídeo desejado
print("Digite o URL da página que contém o vídeo desejado:")
local page_url = io.read()

-- Extrair o URL do vídeo da página web
local video_url = extract_video_url(page_url)

-- Se encontrou o URL do vídeo, baixar e reproduzir o vídeo localmente
if video_url then
  print("Baixando o vídeo...")
  local filename = "video.mp4" -- definir o nome do arquivo de vídeo local
  download(video_url, filename) -- baixar o arquivo de vídeo da internet
  print("Reproduzindo o vídeo...")
  play_video(filename) -- reproduzir o arquivo de vídeo localmente
end

