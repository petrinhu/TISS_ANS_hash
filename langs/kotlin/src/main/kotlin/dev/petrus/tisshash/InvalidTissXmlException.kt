/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
package dev.petrus.tisshash

/**
 * Exceção lançada quando o XML fornecido a [TissHash] é inválido ou
 * rejeitado pelo parser.
 *
 * É [RuntimeException] (unchecked) por escolha de design: a maioria dos
 * chamadores quer falhar rápido em XML malformado, não embrulhar toda chamada
 * em `try/catch`. Quando precisar tratar, basta capturar explicitamente.
 *
 * Mantém a causa raiz via [cause] quando aplicável, para não esconder o erro
 * original do parser SAX/DOM.
 */
public class InvalidTissXmlException : RuntimeException {
    public constructor(message: String) : super(message)
    public constructor(message: String, cause: Throwable?) : super(message, cause)
}
