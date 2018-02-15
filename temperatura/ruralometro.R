# Repórter Brasil (http://ruralometro.reporterbrasil.org.br/)
# Simone Harnik (https://br.linkedin.com/in/simone-harnik-58018a11)
# Programa para calcular as temperaturas dos deputados de acordo com suas votações e autoria de projetos

library(readxl) #Lê as planilhas
library(ggplot2) #Faz os gráficos
library(plyr) #Manipulação de datasets

#Lê projetos e prepara a contagem
projetos_autoria <- read_excel("projs_dep_eleitos_15_01_2018.xls")

projetos_autoria$pontos_autoria<-NA
projetos_autoria$pontos_autoria[projetos_autoria$Qual_avaliacao=="Favorável"]<-1
projetos_autoria$pontos_autoria[projetos_autoria$Qual_avaliacao=="Desfavorável"]<--1
projetos_autoria$pontos_autoria[projetos_autoria$Qual_avaliacao=="Indefinido"]<-0
projetos_autoria$pontos_autoria[is.na(projetos_autoria$Qual_avaliacao)]<-0
projetos_autoria$pontos_autoria<-as.numeric(projetos_autoria$pontos_autoria)


#Criamos a base de projetos por CPF
projetos_CPF<-aggregate(pontos_autoria~CPF, projetos_autoria, sum)


#Encontramos o maior valor absoluto
maximo_abs_autoria<-max(abs(projetos_CPF$pontos_autoria))

#Pontuamos autoria com 1/maximo_abs_autoria
projetos_CPF$pontos_autoria<-projetos_CPF$pontos_autoria/maximo_abs_autoria

#Removemos os objetos não mais utilizados
rm(list= ls()[!(ls() %in% c('projetos_CPF'))])
colnames(projetos_CPF)<-c("Politico_CPF", "pontos_autoria")

#Inserimos a base de votações
votacoes <- read_excel("votos_eleitos_15_01_2018.xls")

votacoes$relev<-NA
votacoes$relev[votacoes$Projeto_Relevancia=="Pouco relevante"]<-1
votacoes$relev[votacoes$Projeto_Relevancia=="Relevante"]<-1
votacoes$relev[votacoes$Projeto_Relevancia=="Muito relevante"]<-2
votacoes$relev[is.na(votacoes$Projeto_Relevancia)]<-0

votacoes$avalia<-NA
votacoes$avalia[votacoes$Projeto_Avaliacao=="Desfavorável"]<--1
votacoes$avalia[votacoes$Projeto_Avaliacao=="Favorável"]<-1
votacoes$avalia[votacoes$Projeto_Avaliacao=="Indiferente"]<-0

votacoes$p_votacao_unica<-NA
votacoes$p_votacao_unica[votacoes$Projeto_Voto=="Sim"]<-1
votacoes$p_votacao_unica[votacoes$Projeto_Voto=="Não"]<--1
votacoes$p_votacao_unica[votacoes$Projeto_Voto=="Obstrução"]<--1
votacoes$p_votacao_unica[votacoes$Projeto_Voto=="Abstenção"]<-0
votacoes$p_votacao_unica[votacoes$Projeto_Voto=="Art. 17"]<-NA

#Removemos as linhas com votação NA
excluir<-is.na(votacoes$p_votacao_unica)
votacoes<-subset(votacoes, subset = excluir==FALSE)
rm(excluir)

#Número de votações por parlamentar
numero_vot_deput<-as.data.frame(table(votacoes$Politico_CPF))
colnames(numero_vot_deput)<-c("Politico_CPF", "Num_votacoes")


votacoes$ponto_voto_unico<-votacoes$relev*votacoes$avalia*votacoes$p_votacao_unica
table(votacoes$ponto_voto_unico)


#Selecionamos a média de pontos
partido_e_ponto<-ddply(votacoes, "Politico_CPF", summarize, 
                       Projeto_Data_votacao = max(Projeto_Data_votacao),
      ponto_final_votacoes=mean(ponto_voto_unico))


#Juntamos as tabelas
dados_final<-merge(partido_e_ponto, projetos_CPF, 
                   by="Politico_CPF", all.x=TRUE)

dados_final<-merge(dados_final, votacoes, 
                   by=c("Politico_CPF", "Projeto_Data_votacao"), 
                   all.x=TRUE)
dados_final<-plyr::join(dados_final, votacoes, 
                        by=c("Politico_CPF", "Projeto_Data_votacao"),
                        match="first")


dados_final$pontos_autoria[is.na(dados_final$pontos_autoria)]<-0

#Juntamos o número de votações
dados_final<-merge(dados_final, numero_vot_deput, by="Politico_CPF")

#Removemos tudo o que não é mais útil
rm(list= ls()[!(ls() %in% c('dados_final'))])

#Selecionamos apenas os deputados com 3 ou mais votações
dados_final<-subset(dados_final, subset=dados_final$Num_votacoes>2)

#Acertamos o dataframe
dados_final<-subset(dados_final, select=c(Politico_CPF, 
                                          Politico_Nome_urna_votacao,
                                          Partido_atual, 
                                          ponto_final_votacoes,
                                          pontos_autoria))
dados_final$pontos_autoria[is.na(dados_final$pontos_autoria)]<-0


Proporcao_votos<-1
Proporcao_autoria<-2
dados_final$ESCALA_TECNICA<-dados_final$ponto_final_votacoes*Proporcao_votos+
                            dados_final$pontos_autoria*Proporcao_autoria

#Criando escala do Ruralômetro como termômetro
term<-dados_final$ESCALA_TECNICA
maximo_neg<-max(abs(dados_final$ESCALA_TECNICA[dados_final$ESCALA_TECNICA<0]))
maximo_pos<-max(dados_final$ESCALA_TECNICA)
term<-ifelse(term>=0, (term/maximo_pos)*(-1.3) + 37.3, (term/maximo_neg)*(-4.7) + 37.3)
dados_final$TEMPERATURA<-term


#Criamos média por partido
media_partido<-ddply(dados_final, "Partido_atual", 
                     summarize, 
                     media_part=mean(TEMPERATURA))
media_partido$posicao<-rank(media_partido$media_part)

dados_final$Partido_atual<-as.factor(dados_final$Partido_atual)

for(i in 1:25){
  dados_final$Partido_atual<-relevel(dados_final$Partido_atual, 
                                     media_partido$Partido_atual[media_partido$posicao==26-i])
}



#Lógica do termômetro
ggplot(dados_final, aes(y = TEMPERATURA, x=Partido_atual))+
  geom_point(data= dados_final, aes(y=TEMPERATURA, colour=TEMPERATURA))+
  scale_colour_gradientn(colours = c('#006837',
                                     '#fee08b', '#fee08b', '#fdae61',
                                     '#fdae61','#f46d43','#d73027','#a50026'))+
  xlab("Partido atual")+
  ylab("Temperatura no Ruralômetro")+
  theme_bw()+
  theme(legend.position = "none") 



##############################################################################
plot(density(term), main="", ylab="Densidade")
write.csv2(dados_final, "dados_ruralometro_50_50.csv")
