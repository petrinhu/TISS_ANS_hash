/*
 * SPDX-License-Identifier: MIT
 * Copyright (c) Petrus Silva Costa
 */
package dev.petrus.tisshash;

/**
 * Exceção lançada quando o XML fornecido a {@link TissHash} é inválido
 * ou rejeitado pelo parser.
 *
 * <p>É {@link RuntimeException} (unchecked) por escolha de design: a maioria
 * dos chamadores quer falhar rápido em XML malformado, não embrulhar todas
 * as chamadas em {@code try/catch}. Quando precisar tratar, basta capturar
 * explicitamente.</p>
 *
 * <p>Mantém a causa raiz via {@link Throwable#getCause()} quando aplicável,
 * para não esconder o erro original do parser SAX/DOM.</p>
 */
public class InvalidTissXmlException extends RuntimeException {

    private static final long serialVersionUID = 1L;

    /**
     * @param message descrição do erro
     */
    public InvalidTissXmlException(String message) {
        super(message);
    }

    /**
     * @param message descrição do erro
     * @param cause causa original (ex.: {@code SAXParseException})
     */
    public InvalidTissXmlException(String message, Throwable cause) {
        super(message, cause);
    }
}
