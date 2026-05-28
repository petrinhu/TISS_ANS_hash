<?php

declare(strict_types=1);

/**
 * tiss-hash — port PHP do hash MD5 do epilogo TISS/ANS.
 *
 * Especificacao canonica: ver `docs/SPEC.md` na raiz do repositorio.
 * Implementacao de referencia: `conformance/reference.py` (Python + lxml).
 *
 * Este arquivo bate byte-a-byte com a referencia nos 15 vetores em
 * `conformance/vectors.json`. As 15 ambiguidades canonicas estao
 * documentadas em `conformance/AMBIGUITY_NOTES.md` e replicadas aqui.
 *
 * ---------------------------------------------------------------------------
 * Decisao de parser: DOMDocument (ext-dom)
 * ---------------------------------------------------------------------------
 * Avaliadas tres opcoes:
 *
 * - DOMDocument (ESCOLHIDA): DOM W3C, ext-dom faz parte da stdlib PHP em
 *   praticamente toda distribuicao, libxml2 por baixo. Preserva nos
 *   XML_COMMENT_NODE por padrao (necessario pra reproduzir a ambiguidade
 *   #2 — comentarios entram no concat). Suporta getElementsByTagNameNS
 *   para localizar <ans:hash> por namespace+localname. Walker recursivo
 *   trivial via childNodes.
 *
 * - SimpleXML: API ergonomica mas omite comentarios (XML_COMMENT_NODE nao
 *   exposto), perde fidelidade de namespace em alguns cenarios, e
 *   coerce de tipos pode normalizar valores. Descartado.
 *
 * - XMLReader: streaming pull-parser, exigiria reconstruir manualmente
 *   o conceito de folha (track de pilha + lookahead). Sem ganho real de
 *   performance pro tamanho tipico de XML TISS (< 5 MB). Descartado.
 *
 * ---------------------------------------------------------------------------
 * Hardening libxml (XXE / billion-laughs)
 * ---------------------------------------------------------------------------
 * Em PHP 8.0+ `libxml_disable_entity_loader()` foi DEPRECATED e em PHP
 * 8.4 foi REMOVIDA. O caminho moderno e:
 *
 *   1. `libxml_set_external_entity_loader(static fn() => null)` —
 *      bloqueia qualquer tentativa de resolver entidade externa via
 *      retorno null (libxml interpreta como "nao foi possivel resolver").
 *   2. Flag `LIBXML_NONET` no parse — proibe acesso a rede (file://,
 *      http://, ftp://) na resolucao de entidades.
 *   3. NAO usar `LIBXML_DTDLOAD`. Combinado com 1+2, DTDs externos sao
 *      ignorados em silencio mesmo se referenciados no DOCTYPE.
 *
 * Sobre `LIBXML_NOENT`: NECESSARIO para reproduzir a ambiguidade #4
 * (entidades XML predefinidas como &amp; &lt; &gt; &quot; &apos; sao
 * DEcodificadas pelo parser antes do concat). Sem essa flag, alguns
 * builds de libxml deixam entidades por substituir e o vetor
 * `syn_entidades_xml.xml` falha. Em DOMDocument, `LIBXML_NOENT` afeta
 * APENAS entidades predefinidas + entidades internas declaradas no
 * DTD interno; entidades externas continuam bloqueadas pelo combo 1+2.
 *
 * ---------------------------------------------------------------------------
 * Encoding
 * ---------------------------------------------------------------------------
 * - Arquivo declara `encoding="iso-8859-1"` (caso comum TISS) ou
 *   `encoding="utf-8"`. DOMDocument le a declaracao via libxml2 e
 *   armazena internamente em UTF-8. Strings extraidas via `textContent`
 *   ja vem em UTF-8 — basta encodar a string concatenada para bytes
 *   UTF-8 (que e o que `md5()` do PHP faz por padrao, ja que strings
 *   PHP sao byte-arrays).
 * - BOM UTF-8 (`EF BB BF`) e removido antes do parse — DOMDocument as
 *   vezes engasga com BOM dependendo da versao do libxml. Strip
 *   defensivo + manter a declaracao XML intacta.
 *
 * @license MIT
 * @author Petrus Silva Costa <petrinhu@yahoo.com.br>
 */

namespace TissHash;

use DOMComment;
use DOMDocument;
use DOMElement;
use DOMNode;
use DOMProcessingInstruction;

/**
 * Classe utilitaria com a API publica do calculo de hash TISS/ANS.
 *
 * Todos os metodos sao estaticos, sem estado mutavel. A classe e `final`
 * para nao permitir extensao acidental que mude semantica do hash (qualquer
 * mudanca de comportamento e violacao do contrato definido em
 * `conformance/vectors.json`).
 *
 * Uso tipico:
 *
 * ```php
 * use TissHash\TissHash;
 *
 * $hash = TissHash::hashTiss(file_get_contents('lote.xml'));
 * // ou
 * $hash = TissHash::hashTissFile('lote.xml');
 * ```
 */
final class TissHash
{
    /**
     * Namespace XML do Padrao TISS/ANS.
     *
     * Apesar do prefixo convencional ser `ans:`, o que conta e o namespace
     * URI: qualquer prefixo serve, desde que mapeie pra esta URI.
     */
    public const TISS_NAMESPACE = 'http://www.ans.gov.br/padroes/tiss/schemas';

    /**
     * BOM UTF-8 (`EF BB BF`).
     *
     * Padrao TISS proibe BOM, mas a referencia aceita defensivamente
     * (ambiguidade #11). Removemos antes do parse pra evitar variacoes
     * de comportamento entre versoes de libxml2.
     */
    private const UTF8_BOM = "\xEF\xBB\xBF";

    /**
     * Bloqueia construcao: classe e puramente estatica.
     *
     * @codeCoverageIgnore
     */
    private function __construct()
    {
    }

    /**
     * Calcula o hash MD5 canonico do epilogo TISS/ANS a partir dos bytes do XML.
     *
     * Algoritmo (ver `docs/SPEC.md` para detalhes):
     *
     * 1. Parse do XML com `DOMDocument` (libxml2), hardened contra XXE.
     * 2. Zerar o conteudo do primeiro `<ans:hash>` encontrado.
     * 3. Concatenar o texto de cada NO-FOLHA (Element ou Comment sem
     *    filhos Element/Comment/PI) em ordem de documento.
     * 4. MD5 dos bytes UTF-8 da string concatenada.
     * 5. Retornar hex minusculo (32 caracteres).
     *
     * @param string $xmlBytes Bytes brutos do XML. PHP strings sao binary-safe;
     *                         passe o resultado de `file_get_contents()` ou
     *                         equivalente. Encoding declarado na declaracao
     *                         XML interna (geralmente `iso-8859-1`).
     *
     * @return string Hash MD5 em hexadecimal minusculo, 32 caracteres.
     *
     * @throws InvalidTissXmlException Se o XML estiver malformado, vazio,
     *                                 ou for rejeitado pelo parser libxml2
     *                                 (incluindo violacao de DTD externo).
     */
    public static function hashTiss(string $xmlBytes): string
    {
        if ($xmlBytes === '') {
            throw new InvalidTissXmlException(
                'XML vazio: hash_tiss requer bytes nao-vazios.'
            );
        }

        // Strip BOM UTF-8 se presente (defensivo; libxml as vezes engasga).
        if (\str_starts_with($xmlBytes, self::UTF8_BOM)) {
            $xmlBytes = \substr($xmlBytes, \strlen(self::UTF8_BOM));
        }

        $dom = self::parseHardened($xmlBytes);

        // Zerar o conteudo do primeiro <ans:hash>. Comportamento da
        // referencia: `root.find(".//ans:hash", NS)` pega o primeiro.
        // Multiplos <ans:hash> = comportamento NAO fixado (ambiguidade #9).
        $hashNodes = $dom->getElementsByTagNameNS(self::TISS_NAMESPACE, 'hash');
        if ($hashNodes->length > 0) {
            $hashEl = $hashNodes->item(0);
            // Substituir conteudo por string vazia. Remover todos filhos
            // (que podem ser text node com o hash antigo, ou ate elementos).
            while ($hashEl->firstChild !== null) {
                $hashEl->removeChild($hashEl->firstChild);
            }
        }

        $partes = [];
        self::walkLeaves($dom->documentElement, $partes);
        $payload = \implode('', $partes);

        // PHP strings sao byte-arrays. textContent / nodeValue do DOMDocument
        // ja vem em UTF-8 (libxml normaliza no parse), entao `md5($payload)`
        // calcula o digest dos bytes UTF-8 corretos.
        return \md5($payload);
    }

    /**
     * Atalho conveniente que le um arquivo XML do disco e calcula o hash.
     *
     * @param string $path Caminho absoluto ou relativo ao arquivo XML.
     *
     * @return string Hash MD5 em hexadecimal minusculo, 32 caracteres.
     *
     * @throws InvalidTissXmlException Se o arquivo nao puder ser lido ou se
     *                                 o XML for invalido.
     */
    public static function hashTissFile(string $path): string
    {
        // Suprimir warning padrao do file_get_contents em falha; lidar
        // explicitamente. ErrorException nao e relancada pra manter API
        // simples — qualquer falha vira InvalidTissXmlException com causa.
        $raw = @\file_get_contents($path);
        if ($raw === false) {
            $err = \error_get_last()['message'] ?? 'erro desconhecido';
            throw new InvalidTissXmlException(
                \sprintf('falha ao ler arquivo "%s": %s', $path, $err)
            );
        }
        return self::hashTiss($raw);
    }

    // -----------------------------------------------------------------------
    // Internos
    // -----------------------------------------------------------------------

    /**
     * Faz o parse seguro do XML com DOMDocument.
     *
     * Hardening aplicado:
     *
     * - `libxml_set_external_entity_loader` retornando null bloqueia
     *   resolucao de qualquer entidade externa (XXE).
     * - `LIBXML_NONET` impede o parser de fazer requests de rede mesmo
     *   se uma entidade declarada apontar para http://.
     * - `LIBXML_NOENT` substitui entidades predefinidas (`&amp;` etc.)
     *   pelo seu valor literal — necessario para conformance #4.
     * - Erros do libxml capturados via `libxml_use_internal_errors` para
     *   nao poluir output e relancados como excecao tipada.
     *
     * @throws InvalidTissXmlException
     */
    private static function parseHardened(string $xmlBytes): DOMDocument
    {
        // Bloqueia entidades externas (XXE). Em PHP 8.0+ esta e a forma
        // suportada; libxml_disable_entity_loader foi removida em PHP 8.4.
        //
        // Nota: o retorno de libxml_set_external_entity_loader varia entre
        // versoes do PHP (algumas devolvem bool, outras o callable
        // anterior, outras null). Por isso NAO tentamos restaurar o
        // loader anterior aqui: o "null loader" e seguro por construcao
        // (qualquer chamada subsequente que precise resolver entidade
        // externa simplesmente nao encontra resolver e falha). Aplicacoes
        // que precisem de outro loader devem reinstalar o seu apos chamar
        // a lib.
        \libxml_set_external_entity_loader(
            static fn(): null => null
        );

        $prevUseErrors = \libxml_use_internal_errors(true);
        \libxml_clear_errors();

        try {
            $dom = new DOMDocument();
            // `preserveWhiteSpace` default e true: manter pra preservar
            // whitespace dentro de valores (ambiguidade #7).
            $dom->preserveWhiteSpace = true;
            // `formatOutput` so afeta saida; nao mexer.

            $ok = $dom->loadXML(
                $xmlBytes,
                \LIBXML_NONET | \LIBXML_NOENT
            );

            if ($ok === false) {
                $errors = \libxml_get_errors();
                $msg = self::formatLibxmlErrors($errors);
                throw new InvalidTissXmlException(
                    'XML invalido para hash TISS: ' . $msg
                );
            }

            if ($dom->documentElement === null) {
                throw new InvalidTissXmlException(
                    'XML invalido para hash TISS: documento sem elemento raiz.'
                );
            }

            return $dom;
        } finally {
            \libxml_clear_errors();
            \libxml_use_internal_errors($prevUseErrors);
        }
    }

    /**
     * Walker recursivo em ordem de documento que coleta texto de
     * nos-folha (Element ou Comment sem filhos Element/Comment/PI).
     *
     * Definicao de "folha" (espelha `len(el) == 0` do lxml na referencia):
     *
     * - Element sem filhos Element/Comment/ProcessingInstruction = folha.
     *   Filhos Text NAO contam (TISS nao tem conteudo misto; um Element
     *   com so Text dentro e folha de valor).
     * - Comment sem filhos = folha (nunca tem filhos; sempre folha).
     * - Text/CDATA isolados: tratados via `textContent` do Element pai.
     *
     * @param list<string> $partes Acumulador (passado por referencia).
     */
    private static function walkLeaves(DOMNode $node, array &$partes): void
    {
        $type = $node->nodeType;

        if ($type === \XML_ELEMENT_NODE || $type === \XML_COMMENT_NODE) {
            $hasStructuredChild = false;
            if ($node->hasChildNodes()) {
                foreach ($node->childNodes as $child) {
                    $ct = $child->nodeType;
                    if ($ct === \XML_ELEMENT_NODE
                        || $ct === \XML_COMMENT_NODE
                        || $ct === \XML_PI_NODE
                    ) {
                        $hasStructuredChild = true;
                        break;
                    }
                }
            }

            if (!$hasStructuredChild) {
                // Folha. Coleta texto:
                // - Comment: `nodeValue` e o texto entre <!-- e -->.
                // - Element: `textContent` concatena Text/CDATA filhos.
                //   Equivale ao `.text` do ElementTree em folha (sem
                //   conteudo misto, sao identicos).
                if ($node instanceof DOMComment) {
                    $partes[] = $node->nodeValue ?? '';
                } elseif ($node instanceof DOMElement) {
                    $partes[] = $node->textContent ?? '';
                }
                return;
            }
        }

        // Nao-folha (ou outro tipo de no): descer recursivo.
        if ($node->hasChildNodes()) {
            foreach ($node->childNodes as $child) {
                self::walkLeaves($child, $partes);
            }
        }
    }

    /**
     * Formata uma lista de erros de libxml em uma unica mensagem legivel.
     *
     * @param list<\LibXMLError> $errors
     */
    private static function formatLibxmlErrors(array $errors): string
    {
        if ($errors === []) {
            return 'parser nao reportou detalhe (verifique sintaxe XML)';
        }
        $first = $errors[0];
        $msg = \trim($first->message);
        return \sprintf(
            'linha %d, coluna %d: %s',
            $first->line,
            $first->column,
            $msg
        );
    }
}
