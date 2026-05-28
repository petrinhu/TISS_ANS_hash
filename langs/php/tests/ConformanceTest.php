<?php

declare(strict_types=1);

namespace TissHash\Tests;

use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use TissHash\InvalidTissXmlException;
use TissHash\TissHash;

/**
 * Suite de conformidade: a lib `TissHash` deve bater todos os vetores
 * canonicos definidos em `conformance/vectors.json` na raiz do repo.
 *
 * Cada vetor vira um dataset nomeado pelo `id`, facilitando ler a saida
 * do `phpunit --testdox`.
 */
final class ConformanceTest extends TestCase
{
    /**
     * Caminho absoluto para `conformance/` na raiz do repo, resolvido a
     * partir da localizacao deste arquivo (`langs/php/tests/`).
     */
    private static function conformanceDir(): string
    {
        return \dirname(__DIR__, 3) . '/conformance';
    }

    /**
     * Carrega `vectors.json` e expoe cada vetor como dataset PHPUnit.
     *
     * Campo `expect` (ver schema do manifesto):
     * - ausente ou `"hash"` => vetor POSITIVO (compara `expected_md5`).
     * - `"error"`           => vetor NEGATIVO (port deve lancar excecao).
     *
     * @return iterable<string, array{string, ?string, string}>
     */
    public static function vectorsProvider(): iterable
    {
        $path = self::conformanceDir() . '/vectors.json';
        if (!\is_file($path)) {
            self::fail("vectors.json ausente em $path");
        }

        $raw = \file_get_contents($path);
        if ($raw === false) {
            self::fail("falha ao ler $path");
        }

        $manifest = \json_decode($raw, true, flags: \JSON_THROW_ON_ERROR);
        $vectors = $manifest['vectors'] ?? [];

        foreach ($vectors as $v) {
            $expect = $v['expect'] ?? 'hash';
            yield $v['id'] => [$v['input'], $v['expected_md5'] ?? null, $expect];
        }
    }

    /**
     * Cada vetor:
     * - POSITIVO (`expect` ausente/`"hash"`): calcula o hash e compara.
     * - NEGATIVO (`expect === "error"`): deve lancar InvalidTissXmlException.
     */
    #[DataProvider('vectorsProvider')]
    public function testVector(string $inputRel, ?string $expectedMd5, string $expect): void
    {
        $inputPath = self::conformanceDir() . '/' . $inputRel;
        $this->assertFileExists($inputPath, "input ausente: $inputPath");

        $raw = \file_get_contents($inputPath);
        $this->assertIsString($raw);

        if ($expect === 'error') {
            try {
                $got = TissHash::hashTiss($raw);
                $this->fail(\sprintf(
                    'esperado InvalidTissXmlException para vetor negativo %s, '
                    . 'mas obteve hash %s',
                    $inputRel,
                    $got
                ));
            } catch (InvalidTissXmlException $e) {
                // Esperado: vetor negativo rejeitado. Mensagem nao deve
                // vazar o XML original (PII).
                $this->assertNotEmpty($e->getMessage());
                $this->addToAssertionCount(1);
            }
            return;
        }

        $this->assertNotNull(
            $expectedMd5,
            "vetor positivo $inputRel sem expected_md5 no manifesto"
        );

        $got = TissHash::hashTiss($raw);

        $this->assertSame(
            $expectedMd5,
            $got,
            \sprintf('hash divergente para %s: obtido %s, esperado %s', $inputRel, $got, $expectedMd5)
        );
    }

    /**
     * Sanidade: o manifesto carrega e tem >= 5 vetores nucleo.
     */
    public function testManifestContainsCoreVectors(): void
    {
        $path = self::conformanceDir() . '/vectors.json';
        $raw = \file_get_contents($path);
        $this->assertIsString($raw);

        $manifest = \json_decode($raw, true, flags: \JSON_THROW_ON_ERROR);
        $ids = \array_column($manifest['vectors'], 'id');

        $nucleo = [
            'syn_minimal.xml',
            'syn_acento.xml',
            'syn_empty.xml',
            'syn_crlf_value.xml',
            'syn_multi_guia.xml',
        ];

        foreach ($nucleo as $id) {
            $this->assertContains($id, $ids, "vetor nucleo ausente: $id");
        }
        $this->assertGreaterThanOrEqual(20, \count($ids), 'esperado >= 20 vetores no manifesto');
    }

    /**
     * Vetor negativo: >1 <ans:hash> do namespace TISS deve ser rejeitado
     * (AMBIGUITY_NOTES.md §9 / A-COV2).
     */
    public function testMultipleHashRaisesInvalidTissXmlException(): void
    {
        $xml = "<?xml version='1.0' encoding='iso-8859-1'?>"
            . '<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">'
            . '<ans:epilogo><ans:hash></ans:hash><ans:hash></ans:hash></ans:epilogo>'
            . '</ans:mensagemTISS>';
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTiss($xml);
    }

    /**
     * Vetor negativo: BOM UTF-16 (FF FE) deve ser rejeitado (fora de escopo;
     * AMBIGUITY_NOTES.md §11b / A-COV5).
     */
    public function testUtf16BomRaisesInvalidTissXmlException(): void
    {
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTiss("\xFF\xFE<\x00");
    }

    /**
     * Vetor negativo: BOM UTF-32-LE (FF FE 00 00) deve ser rejeitado ANTES de
     * ser confundido com UTF-16-LE (FF FE), que e seu prefixo.
     */
    public function testUtf32BomRaisesInvalidTissXmlException(): void
    {
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTiss("\xFF\xFE\x00\x00<\x00\x00\x00");
    }

    /**
     * Namespace TISS como DEFAULT (xmlns= sem prefixo): <hash> deve casar
     * pela URI, nao pelo prefixo literal.
     */
    public function testDefaultNamespaceMatchesByUri(): void
    {
        $path = self::conformanceDir() . '/inputs/syn_default_ns.xml';
        $this->assertFileExists($path);
        $got = TissHash::hashTiss(\file_get_contents($path));
        // Sanidade: o <hash> default-ns foi zerado (VALOR_SEM_PREFIXO
        // continua no concat; hash diferiria se nao casasse a URI).
        $this->assertSame('3ad92bd5ebbf35364433b897d08bf23a', $got);
    }

    /**
     * Documento SEM <ans:hash> e VALIDO: concatena tudo, sem erro.
     */
    public function testMissingHashElementIsValid(): void
    {
        $path = self::conformanceDir() . '/inputs/syn_sem_hash.xml';
        $this->assertFileExists($path);
        $got = TissHash::hashTiss(\file_get_contents($path));
        $this->assertSame('710a997000c9780901be02fafe449c64', $got);
    }

    /**
     * `hashTissFile` deve produzir o mesmo resultado de `hashTiss` lendo
     * o mesmo arquivo.
     */
    public function testHashTissFileMatchesHashTiss(): void
    {
        $path = self::conformanceDir() . '/inputs/syn_minimal.xml';
        $this->assertFileExists($path);

        $viaBytes = TissHash::hashTiss(\file_get_contents($path));
        $viaFile = TissHash::hashTissFile($path);

        $this->assertSame($viaBytes, $viaFile);
        $this->assertSame('3aa0c578c95cdb861a125f480a8a4de5', $viaFile);
    }

    /**
     * XML malformado dispara InvalidTissXmlException (subclasse de RuntimeException).
     */
    public function testInvalidXmlRaisesInvalidTissXmlException(): void
    {
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTiss('<isto-nao-fecha>');
    }

    /**
     * String vazia tambem e rejeitada (fail-fast).
     */
    public function testEmptyInputRaisesInvalidTissXmlException(): void
    {
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTiss('');
    }

    /**
     * Arquivo inexistente vira InvalidTissXmlException com causa em mensagem.
     */
    public function testMissingFileRaisesInvalidTissXmlException(): void
    {
        $this->expectException(InvalidTissXmlException::class);
        TissHash::hashTissFile('/nao/existe/arquivo.xml');
    }

    /**
     * A constante TISS_NAMESPACE bate com a URI oficial do padrao.
     */
    public function testTissNamespaceConstant(): void
    {
        $this->assertSame(
            'http://www.ans.gov.br/padroes/tiss/schemas',
            TissHash::TISS_NAMESPACE
        );
    }

    /**
     * Inline: XML minimo com hash poluido + sem texto nas folhas
     * deve produzir MD5 da string vazia. Sanidade do passo de zeragem.
     */
    public function testInlineMinimalProducesEmptyStringMd5(): void
    {
        $xml = "<?xml version='1.0' encoding='utf-8'?>"
            . '<ans:mensagemTISS xmlns:ans="http://www.ans.gov.br/padroes/tiss/schemas">'
            . '<ans:epilogo><ans:hash>QUALQUER</ans:hash></ans:epilogo>'
            . '</ans:mensagemTISS>';
        $this->assertSame(
            'd41d8cd98f00b204e9800998ecf8427e',
            TissHash::hashTiss($xml)
        );
    }
}
