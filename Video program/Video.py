# Importar as bibliotecas necessárias
import tkinter as tk
import webbrowser
import requests
from bs4 import BeautifulSoup

# Criar uma janela tkinter
window = tk.Tk()
window.title("Tela de vídeo")
window.geometry("800x600")

# Definir uma função para obter o URL do vídeo do YouTube a partir de um endereço online
def get_video_url(online_address):
    # Fazer uma requisição HTTP para o endereço online
    response = requests.get(online_address)
    # Verificar se a resposta foi bem sucedida
    if response.status_code == 200:
        # Usar o BeautifulSoup para analisar o conteúdo HTML da resposta
        soup = BeautifulSoup(response.content, "html.parser")
        # Procurar a tag <iframe> que contém o URL do vídeo do YouTube
        iframe = soup.find("iframe")
        # Retornar o valor do atributo src da tag <iframe>
        return iframe["src"]
    else:
        # Retornar uma mensagem de erro se a resposta não foi bem sucedida
        return "Não foi possível obter o URL do vídeo do YouTube"

# Definir uma função para abrir o URL do vídeo do YouTube em um navegador web
def open_video(url):
    webbrowser.open(url)

# Criar um rótulo para exibir o endereço online do vídeo do YouTube
label = tk.Label(window, text="Endereço online do vídeo do YouTube:")
label.pack()

# Criar uma entrada para digitar o endereço online do vídeo do YouTube
entry = tk.Entry(window)
entry.pack()

# Criar um botão para obter o URL do vídeo do YouTube e abri-lo em um navegador web
button = tk.Button(window, text="Abrir vídeo", command=lambda: open_video(get_video_url(entry.get())))
button.pack()

# Iniciar o loop principal da janela tkinter
window.mainloop()
