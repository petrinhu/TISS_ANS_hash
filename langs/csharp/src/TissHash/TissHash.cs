// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Petrus Silva Costa
//
// tiss-hash (.NET) — Hash MD5 do epilogo <ans:hash> em XMLs do Padrao TISS/ANS.
//
// Spec canonica: docs/SPEC.md na raiz do repositorio.
// Implementacao de referencia: conformance/reference.py (Python + lxml).
// Este port bate byte-a-byte com a referencia nos 15 vetores em
// conformance/vectors.json.
//
// ---------------------------------------------------------------------------
// Decisao de parser XML
// ---------------------------------------------------------------------------
// Avaliadas tres opcoes da BCL:
//
//   1) System.Xml.Linq.XDocument (ESCOLHIDA) — LINQ to XML, API moderna,
//      namespace-aware (XName/XNamespace), e — DETALHE CRITICO — PRESERVA
//      comentarios (XComment) como nodes filhos em XContainer.Nodes() por
//      padrao. Isso reproduz a ambiguidade #2 da referencia (comentarios
//      ENTRAM no concat) sem flag adicional. Zero dependencia externa.
//
//   2) System.Xml.XmlDocument — DOM W3C legacy. Mais verboso e, por padrao
//      em alguns paths, pode tratar XmlNodeType.Comment de forma diferente.
//      LINQ to XML tem a mesma capacidade com API mais limpa. Descartado.
//
//   3) System.Xml.XmlReader (streaming pull) — exigiria reconstrucao manual
//      da nocao de "elemento-folha" e gestao de stack. Sem ganho real para
//      XMLs TISS < 10 MB. Usado APENAS internamente como subsistema de
//      leitura de bytes (com DTD desabilitada) que alimenta o XDocument.
//
// ---------------------------------------------------------------------------
// Algoritmo (resumo — ver docs/SPEC.md)
// ---------------------------------------------------------------------------
// 1. Parse do XML (encoding detectado do proprio prologo / BOM).
// 2. Localizar o primeiro <ans:hash> e tratar seu conteudo como string vazia.
// 3. Concatenar o textContent de cada NO-FOLHA (Element ou Comment cujos
//    filhos NAO contem Element/Comment/PI) em ordem de documento.
// 4. MD5 sobre os bytes UTF-8 da string concatenada.
// 5. Hex minusculo, 32 caracteres.
//
// AMBIGUIDADES FIXADAS (ver conformance/AMBIGUITY_NOTES.md):
//  - Comentarios XML ENTRAM no concat (#2).
//  - CDATA = texto literal (#3).
//  - Atributos NAO entram (#5).
//  - Prefixo de namespace irrelevante; apenas URI conta (#6).
//  - Encoding dos bytes do MD5 = UTF-8 (NAO ISO-8859-1 — manual erra) (#1).

using System.IO;
using System.Security.Cryptography;
using System.Text;
using System.Xml;
using System.Xml.Linq;

namespace TissHash;

/// <summary>
/// API publica do port .NET do <c>tiss-hash</c>. Calcula o hash MD5 canonico
/// do <c>&lt;ans:hash&gt;</c> em XMLs do Padrao TISS/ANS (saude suplementar
/// brasileira), reproduzindo byte-a-byte a referencia Python.
/// </summary>
/// <remarks>
/// Classe estatica: sem estado mutavel global, thread-safe por construcao
/// (cada chamada cria seu proprio reader/parser/hasher; o registro do
/// <see cref="System.Text.CodePagesEncodingProvider"/> e idempotente e
/// feito uma unica vez no construtor estatico).
/// </remarks>
public static class TissHash
{
    /// <summary>
    /// URI do namespace XML do Padrao TISS/ANS. Usado para localizar
    /// <c>&lt;ans:hash&gt;</c> de forma robusta a qualquer prefixo
    /// (e.g. <c>tiss:hash</c>, <c>ns0:hash</c>) — o que conta e a URI.
    /// </summary>
    public const string TissNamespace =
        "http://www.ans.gov.br/padroes/tiss/schemas";

    /// <summary>Versao deste port (SemVer).</summary>
    public const string Version = "0.1.0";

    private static readonly XName HashElementName =
        XName.Get("hash", TissNamespace);

    /// <summary>
    /// Construtor estatico: registra o provider de code pages legacy
    /// (necessario para o <see cref="XmlReader"/> conseguir decodificar
    /// arquivos declarados como <c>encoding="iso-8859-1"</c>, que NAO vem
    /// no runtime .NET Core+ por padrao). Idempotente.
    /// </summary>
    static TissHash()
    {
        Encoding.RegisterProvider(CodePagesEncodingProvider.Instance);
    }

    /// <summary>
    /// Calcula o hash MD5 canonico do epilogo TISS/ANS a partir dos bytes
    /// do XML completo. Retorna 32 caracteres hex minusculos.
    /// </summary>
    /// <param name="xml">Bytes do documento XML (com ou sem BOM UTF-8).</param>
    /// <returns>MD5 em hex lowercase (32 chars).</returns>
    /// <exception cref="ArgumentNullException"><paramref name="xml"/> e nulo.</exception>
    /// <exception cref="InvalidTissXmlException">
    /// XML mal-formado, vazio, ou rejeitado pelo parser (DTD proibida etc.).
    /// </exception>
    public static string HashTiss(byte[] xml)
    {
        ArgumentNullException.ThrowIfNull(xml);

        // Strip BOM UTF-8 se presente, ANTES de entregar ao XmlReader.
        // Motivo: alguns paths do reader sao sensiveis a BOM + encoding
        // declaration; strippar simplifica e nao perde info (BOM == marker).
        var slice = StripUtf8Bom(xml);

        XDocument doc;
        try
        {
            // MemoryStream em vez de string: deixa o XmlReader detectar o
            // encoding declarado no prologo (<?xml encoding="iso-8859-1"?>)
            // ou via BOM, exatamente como o lxml/libxml2 fazem.
            using var ms = new MemoryStream(
                slice.Array!, slice.Offset, slice.Count, writable: false);

            var settings = new XmlReaderSettings
            {
                // Seguranca: nunca processar DTD externa nem resolver
                // entidades fora do documento. Padrao moderno do .NET ja
                // proibe XXE em XmlReader, mas explicitamos.
                DtdProcessing = DtdProcessing.Prohibit,
                XmlResolver = null,
                // PRESERVAR comentarios (ambiguidade #2). XmlReader por
                // default ja entrega XmlNodeType.Comment, mas garantimos
                // que IgnoreComments fique false.
                IgnoreComments = false,
                // Preservar whitespace literal — TISS leaf-text pode ter
                // espacos significativos (#7). XDocument.Load expoe
                // whitespace de elementos via Value, entao precisamos
                // do reader nao-normalizador.
                IgnoreWhitespace = false,
                IgnoreProcessingInstructions = true,
                CloseInput = false,
            };

            using var reader = XmlReader.Create(ms, settings);
            // LoadOptions.PreserveWhitespace garante que XText com so
            // espacos nao seja descartado entre tags — e essencial para
            // bater valor de elemento contendo so whitespace puro (#7).
            doc = XDocument.Load(reader, LoadOptions.PreserveWhitespace);
        }
        catch (XmlException ex)
        {
            throw new InvalidTissXmlException(
                $"XML invalido: {ex.Message}", ex);
        }
        catch (InvalidOperationException ex)
        {
            // XmlReader.Create as vezes envolve falhas de encoding aqui.
            throw new InvalidTissXmlException(
                $"falha ao parsear XML: {ex.Message}", ex);
        }

        if (doc.Root is null)
        {
            throw new InvalidTissXmlException("XML sem elemento raiz");
        }

        // Localiza o primeiro <ans:hash> em ordem de documento.
        var hashNode = doc.Descendants(HashElementName).FirstOrDefault();

        // Concat dos textContents das folhas, em ordem de documento.
        var buffer = new StringBuilder(capacity: 4096);
        WalkInOrder(doc.Root, hashNode, buffer);

        // MD5 sobre bytes UTF-8 (NAO ISO-8859-1; ambiguidade #1).
        // MD5.HashData(ReadOnlySpan<byte>) e a API stateless moderna (NET 5+);
        // aloca apenas o array de 16 bytes de retorno.
        var concatBytes = Encoding.UTF8.GetBytes(buffer.ToString());
        var digest = MD5.HashData(concatBytes);
        return Convert.ToHexString(digest).ToLowerInvariant();
    }

    /// <summary>
    /// Atalho conveniente: le o arquivo do disco e calcula
    /// <see cref="HashTiss(byte[])"/>.
    /// </summary>
    /// <param name="path">Caminho do arquivo XML.</param>
    /// <returns>MD5 em hex lowercase (32 chars).</returns>
    /// <exception cref="ArgumentNullException"><paramref name="path"/> e nulo.</exception>
    /// <exception cref="FileNotFoundException">Arquivo nao existe.</exception>
    /// <exception cref="InvalidTissXmlException">XML invalido.</exception>
    public static string HashTissFile(string path)
    {
        ArgumentNullException.ThrowIfNull(path);
        var bytes = File.ReadAllBytes(path);
        return HashTiss(bytes);
    }

    // -----------------------------------------------------------------------
    // Internos
    // -----------------------------------------------------------------------

    /// <summary>
    /// Walker recursivo em ordem de documento (depth-first, pre-order).
    /// Visita apenas <see cref="XElement"/> e <see cref="XComment"/>; emite
    /// o text content quando o no e folha (no sentido da referencia: sem
    /// filhos Element/Comment/PI; filhos Text/CDATA NAO desclassificam).
    /// </summary>
    /// <param name="node">No corrente.</param>
    /// <param name="hashNode">No <c>&lt;ans:hash&gt;</c> a ser zerado (pode ser null).</param>
    /// <param name="buffer">Acumulador da string concatenada.</param>
    private static void WalkInOrder(XNode node, XNode? hashNode, StringBuilder buffer)
    {
        if (node is XElement el)
        {
            if (IsLeafForHash(el))
            {
                if (ReferenceEquals(el, hashNode))
                {
                    // <ans:hash> contribui string vazia (#15).
                    return;
                }
                // Element-folha: concat dos filhos Text/CDATA. XElement.Value
                // ja faz exatamente isso (concat de XText.Value + XCData.Value).
                // Se nao houver filhos, retorna "" — bate com (.text or "")
                // da referencia (#13).
                buffer.Append(el.Value);
                return;
            }
            // Nao-folha: descer recursivamente em ordem de documento.
            foreach (var child in el.Nodes())
            {
                WalkInOrder(child, hashNode, buffer);
            }
        }
        else if (node is XComment comment)
        {
            // XComment e sempre folha — nao tem filhos. Texto literal entre
            // <!-- e --> (ambiguidade #2).
            buffer.Append(comment.Value);
        }
        // XText, XCData, XProcessingInstruction, XDocumentType: ignorados
        // na visita TOP-LEVEL. Texto so e capturado via XElement.Value
        // acima, no contexto da folha-elemento (sem dupla contagem).
    }

    /// <summary>
    /// Decide se um <see cref="XElement"/> e "folha pro hash" no sentido da
    /// referencia: nao tem filhos Element/Comment/PI. Filhos Text/CDATA NAO
    /// desclassificam (TISS nao tem conteudo misto, entao um elemento com
    /// apenas Text/CDATA e folha-de-valor).
    /// </summary>
    private static bool IsLeafForHash(XElement el)
    {
        foreach (var child in el.Nodes())
        {
            if (child is XElement or XComment or XProcessingInstruction)
            {
                return false;
            }
        }
        return true;
    }

    /// <summary>
    /// Devolve um <see cref="ArraySegment{T}"/> sobre <paramref name="bytes"/>
    /// pulando os 3 bytes do BOM UTF-8 (<c>EF BB BF</c>) se presente.
    /// </summary>
    private static ArraySegment<byte> StripUtf8Bom(byte[] bytes)
    {
        if (bytes.Length >= 3
            && bytes[0] == 0xEF
            && bytes[1] == 0xBB
            && bytes[2] == 0xBF)
        {
            return new ArraySegment<byte>(bytes, 3, bytes.Length - 3);
        }
        return new ArraySegment<byte>(bytes, 0, bytes.Length);
    }
}
