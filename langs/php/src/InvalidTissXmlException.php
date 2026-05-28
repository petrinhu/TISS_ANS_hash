<?php

declare(strict_types=1);

namespace TissHash;

use RuntimeException;

/**
 * Excecao para XML de entrada invalido ou rejeitado pela politica de
 * seguranca do parser (XXE, DTD externo, entidade desconhecida).
 *
 * Subclasse de {@see \RuntimeException} para semantica idiomatica PHP:
 * trata-se de uma falha que ocorre durante a operacao (parsing) e que o
 * chamador pode optar por capturar ou propagar.
 *
 * Mensagens NAO contem o XML original (que pode conter PII de pacientes);
 * apenas a falha tecnica do parser (linha/coluna, sintaxe).
 */
class InvalidTissXmlException extends RuntimeException
{
}
