// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Petrus Silva Costa

namespace TissHash;

/// <summary>
/// Excecao lancada quando o XML de entrada e invalido — mal-formado, vazio,
/// ou rejeitado pelo parser por qualquer outra razao (ex.: DTD proibida,
/// declaracao de encoding malformada).
/// </summary>
/// <remarks>
/// E uma excecao "publica" do contrato da biblioteca: callers podem (e
/// devem) discrimina-la via <c>catch (InvalidTissXmlException ex)</c> em
/// vez de capturar <see cref="System.Xml.XmlException"/> direto — o tipo
/// concreto do parser e detalhe de implementacao que pode mudar.
/// A causa original (do parser subjacente) e preservada via
/// <see cref="System.Exception.InnerException"/>.
/// </remarks>
public sealed class InvalidTissXmlException : Exception
{
    /// <summary>Cria a excecao com uma mensagem descritiva.</summary>
    /// <param name="message">Mensagem explicando o motivo da invalidez.</param>
    public InvalidTissXmlException(string message)
        : base(message)
    {
    }

    /// <summary>Cria a excecao com mensagem e causa original.</summary>
    /// <param name="message">Mensagem explicando o motivo da invalidez.</param>
    /// <param name="inner">Excecao subjacente (ex.: <see cref="System.Xml.XmlException"/>).</param>
    public InvalidTissXmlException(string message, Exception inner)
        : base(message, inner)
    {
    }
}
