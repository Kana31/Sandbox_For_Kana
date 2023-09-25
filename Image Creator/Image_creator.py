# Importar as bibliotecas necessárias
import random
import os
import cv2
import numpy as np

# Definir a pasta onde as imagens serão salvas
pasta = "imagens"

# Criar a pasta se ela não existir
if not os.path.exists(pasta):
    os.makedirs(pasta)

# Definir o número de imagens a serem geradas
n_imagens = 31

# Definir o tamanho das imagens em pixels
largura = 1920
altura = 1080

# Definir as cores possíveis para as formas em BGR (azul, verde, vermelho)
cores = [(255, 0, 0), (0, 255, 0), (0, 0, 255), (255, 255, 0), (0, 255, 255), (255, 0, 255)]

# Definir uma função para desenhar uma bola em uma imagem
def desenhar_bola(imagem, centro, raio, cor):
    # Desenhar um círculo preenchido com a cor especificada
    cv2.circle(imagem, centro, raio, cor, -1)

# Definir uma função para desenhar um triângulo em uma imagem
def desenhar_triangulo(imagem, vertices, cor):
    # Desenhar um polígono preenchido com a cor especificada
    cv2.fillPoly(imagem, [vertices], cor)

# Gerar as imagens aleatoriamente
for i in range(n_imagens):
    # Criar uma imagem vazia com fundo branco
    imagem = np.ones((altura, largura, 3), dtype=np.uint8) * 255

    # Escolher duas cores aleatórias para as bolas
    cor_bola1 = random.choice(cores)
    cor_bola2 = random.choice(cores)

    # Escolher dois centros e raios aleatórios para as bolas
    centro_bola1 = (random.randint(0, largura), random.randint(0, altura))
    centro_bola2 = (random.randint(0, largura), random.randint(0, altura))
    raio_bola1 = random.randint(10, 100)
    raio_bola2 = random.randint(10, 100)

    # Desenhar as bolas na imagem
    desenhar_bola(imagem, centro_bola1, raio_bola1, cor_bola1)
    desenhar_bola(imagem, centro_bola2, raio_bola2, cor_bola2)

    # Escolher duas cores aleatórias para os triângulos
    cor_triangulo1 = random.choice(cores)
    cor_triangulo2 = random.choice(cores)

    # Escolher três vértices aleatórios para cada triângulo
    vertices_triangulo1 = np.array([(random.randint(0, largura), random.randint(0, altura)),
                                    (random.randint(0, largura), random.randint(0, altura)),
                                    (random.randint(0, largura), random.randint(0, altura))])
    vertices_triangulo2 = np.array([(random.randint(0, largura), random.randint(0, altura)),
                                    (random.randint(0, largura), random.randint(0, altura)),
                                    (random.randint(0, largura), random.randint(0, altura))])

    # Desenhar os triângulos na imagem
    desenhar_triangulo(imagem, vertices_triangulo1, cor_triangulo1)
    desenhar_triangulo(imagem, vertices_triangulo2, cor_triangulo2)

    # Salvar a imagem na pasta com um nome sequencial
    nome_imagem = f"imagem_{i+1}.png"
    caminho_imagem = os.path.join(pasta,nome_imagem)
    cv2.imwrite(caminho_imagem , imagem)

# Exibir uma mensagem de sucesso
print(f"{n_imagens} imagens foram geradas e salvas na pasta {pasta}.")
