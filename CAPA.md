# Título do Projeto

`CURSO: Segurança da Informação`

`DISCIPLINA: Projeto - Projeto de Infraestrutura`

`Eixo: 3`

Este projeto consiste no desenvolvimento de uma arquitetura de nuvem resiliente e segura na AWS, utilizando Terraform (IaC) para garantir consistência e rastreabilidade. O ambiente é fundamentado nos princípios de Zero Trust, onde todos os ativos (instâncias Windows e Linux) estão confinados em sub-redes privadas sem endereços IP públicos, eliminando a superfície de exposição direta à internet. O acesso administrativo é gerenciado via AWS Systems Manager (SSM), substituindo o uso tradicional de chaves SSH e Bastion Hosts por uma autenticação baseada em identidade e privilégio mínimo via IAM, garantindo auditoria total de comandos e sessões.

Além da segurança de rede, o projeto integra camadas de monitoramento inteligente com Amazon GuardDuty e Amazon Inspector, permitindo a detecção proativa de ameaças e a gestão contínua de vulnerabilidades. Um diferencial estratégico é a implementação de FinOps direto no código, através de um "interruptor financeiro" (Feature Toggling) que condiciona o provisionamento de recursos de alto custo, como NAT Gateways e Client VPNs. Isso permite que o laboratório opere em um modo de custo quase zero para estudos de rotina, sendo escalado para um ambiente de produção simulado apenas durante janelas de teste específicas, otimizando o orçamento sem comprometer o aprendizado técnico.

## Integrantes

* Davi Mateus Gaio
* Gabrielle Vitória Gomes Almeida
* Nicolas Miller
* Yasmin Nascimento de Souza Fernandes
* Pedro Henrique dos Santos

## Orientador

* Marco Antonio da Silva Barbosa


