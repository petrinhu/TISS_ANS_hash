// SPDX-License-Identifier: MIT
// Copyright (c) 2026 Petrus Silva Costa
//
// Suite de conformidade do port C#/.NET — carrega vectors.json e roda os
// 20 vetores de conformancia compartilhados.
//
// Cada vetor e POSITIVO ou NEGATIVO conforme o campo `expect`:
//   - ausente ou "hash" => POSITIVO: comparar byte-a-byte com expected_md5.
//   - "error"           => NEGATIVO: o port DEVE lancar InvalidTissXmlException
//                          (nunca produzir hash). expected_md5 e null.
// Negativos atuais: syn_multi_hash.xml (>1 <ans:hash>, A-COV2),
//                   syn_utf16.xml (encoding fora de escopo, A-COV5).

using System.IO;
using System.Reflection;
using System.Text.Json;
using System.Text.Json.Serialization;
using Xunit;

// Alias para nao colidir o namespace TissHash com a classe estatica TissHash
// quando referenciamos a classe — usar `TissHashLib.HashTiss(...)` fica
// inequivoco no codigo de teste.
using TissHashLib = TissHash.TissHash;

namespace TissHash.Tests;

/// <summary>
/// Testes que carregam <c>conformance/vectors.json</c> e validam que o port
/// C# produz exatamente o mesmo MD5 da referencia para cada vetor.
/// </summary>
public sealed class ConformanceTests
{
    /// <summary>
    /// Caminho absoluto da raiz <c>conformance/</c> no repositorio.
    /// </summary>
    /// <remarks>
    /// Resolvido a partir da localizacao da DLL de teste — independente do
    /// CWD do runner (dotnet test, IDE, CI). De
    /// <c>langs/csharp/tests/TissHash.Tests/bin/Debug/net8.0/</c> subimos
    /// 7 niveis (bin/Debug/net8.0 -> TissHash.Tests -> tests -> csharp ->
    /// langs -> raiz) para chegar na raiz do repo, e descemos em
    /// <c>conformance/</c>.
    /// </remarks>
    private static readonly string ConformanceDir = ResolveConformanceDir();

    private static string ResolveConformanceDir()
    {
        var asmDir = Path.GetDirectoryName(
            typeof(ConformanceTests).Assembly.Location)
            ?? throw new InvalidOperationException(
                "nao consegui descobrir o diretorio da assembly de teste");

        // bin/Debug/net8.0 -> TissHash.Tests (3) -> tests (4) -> csharp (5)
        //                  -> langs (6) -> raiz (7)
        var repoRoot = Path.GetFullPath(
            Path.Combine(asmDir, "..", "..", "..", "..", "..", "..", ".."));
        var conformance = Path.Combine(repoRoot, "conformance");

        if (!Directory.Exists(conformance))
        {
            throw new DirectoryNotFoundException(
                $"diretorio conformance/ nao encontrado em {conformance} " +
                $"(asmDir={asmDir})");
        }
        return conformance;
    }

    /// <summary>Vetor minimal carregado do JSON.</summary>
    public sealed class Vector
    {
        [JsonPropertyName("id")] public string Id { get; set; } = "";
        [JsonPropertyName("input")] public string Input { get; set; } = "";

        // null nos vetores negativos (expect == "error").
        [JsonPropertyName("expected_md5")] public string? ExpectedMd5 { get; set; }

        // Ausente/"hash" => positivo; "error" => negativo (deve rejeitar).
        [JsonPropertyName("expect")] public string? Expect { get; set; }

        [JsonPropertyName("desc")] public string Desc { get; set; } = "";

        /// <summary>True se o vetor exige que o port lance excecao.</summary>
        public bool IsError => string.Equals(Expect, "error",
            StringComparison.Ordinal);
    }

    private sealed class Manifest
    {
        [JsonPropertyName("vectors")] public List<Vector> Vectors { get; set; } = new();
    }

    /// <summary>
    /// MemberData para o <see cref="Theory"/> abaixo. Carrega o manifesto
    /// uma vez e devolve cada vetor como tupla unica.
    /// </summary>
    public static IEnumerable<object[]> AllVectors()
    {
        var vectorsPath = Path.Combine(ConformanceDir, "vectors.json");
        var json = File.ReadAllText(vectorsPath);
        var manifest = JsonSerializer.Deserialize<Manifest>(json,
            new JsonSerializerOptions { PropertyNameCaseInsensitive = true })
            ?? throw new InvalidOperationException(
                $"vectors.json desserializou como null: {vectorsPath}");

        foreach (var v in manifest.Vectors)
        {
            yield return new object[] { v };
        }
    }

    [Theory]
    [MemberData(nameof(AllVectors))]
    public void Conformance_Vector_Matches_Reference(Vector vec)
    {
        var inputPath = Path.Combine(ConformanceDir, vec.Input);
        Assert.True(File.Exists(inputPath),
            $"input ausente: {inputPath} (vetor {vec.Id})");

        var bytes = File.ReadAllBytes(inputPath);

        if (vec.IsError)
        {
            // Vetor NEGATIVO: o port deve rejeitar a entrada com a excecao
            // de contrato — nunca produzir hash de um documento invalido.
            Assert.Throws<InvalidTissXmlException>(
                () => TissHashLib.HashTiss(bytes));
            return;
        }

        // Vetor POSITIVO: hash deve bater byte-a-byte com a referencia.
        Assert.False(string.IsNullOrEmpty(vec.ExpectedMd5),
            $"vetor positivo {vec.Id} sem expected_md5 no manifesto");
        var got = TissHashLib.HashTiss(bytes);
        Assert.Equal(vec.ExpectedMd5, got);
    }

    [Fact]
    public void TissNamespace_Has_Expected_Uri()
    {
        Assert.Equal(
            "http://www.ans.gov.br/padroes/tiss/schemas",
            TissHashLib.TissNamespace);
    }

    [Fact]
    public void HashTissFile_Matches_HashTiss_With_ReadAllBytes()
    {
        var inputPath = Path.Combine(
            ConformanceDir, "inputs", "syn_acento.xml");
        var fromFile = TissHashLib.HashTissFile(inputPath);
        var fromBytes = TissHashLib.HashTiss(File.ReadAllBytes(inputPath));
        Assert.Equal(fromBytes, fromFile);
        // Hash conhecido da referencia: prova UTF-8 nos bytes do MD5
        // (vetor discriminador da ambiguidade #1).
        Assert.Equal("a20afc9a89aadaa2179d03d225337662", fromFile);
    }

    [Fact]
    public void HashTiss_Null_Throws_ArgumentNullException()
    {
        Assert.Throws<ArgumentNullException>(
            () => TissHashLib.HashTiss(null!));
    }

    [Fact]
    public void HashTiss_Malformed_Xml_Throws_InvalidTissXmlException()
    {
        var malformed = System.Text.Encoding.UTF8.GetBytes("<root><sem-fechar>");
        Assert.Throws<InvalidTissXmlException>(
            () => TissHashLib.HashTiss(malformed));
    }

    [Fact]
    public void HashTiss_Empty_Bytes_Throws_InvalidTissXmlException()
    {
        Assert.Throws<InvalidTissXmlException>(
            () => TissHashLib.HashTiss(Array.Empty<byte>()));
    }

    [Fact]
    public void Comment_Contributes_To_Concat_Ambiguity_2()
    {
        // Documento minimal: sem comentario, todas as folhas sao vazias
        // (<ans:hash> zera, demais nao existem) -> MD5("") = d41d8cd9...
        // Com comentario, o texto literal entra no concat -> hash diferente.
        const string ns = "http://www.ans.gov.br/padroes/tiss/schemas";
        var xml = "<?xml version='1.0' encoding='utf-8'?>" +
            $"<ans:mensagemTISS xmlns:ans=\"{ns}\">" +
            "<ans:cabecalho><!-- COMENTARIO --></ans:cabecalho>" +
            "<ans:epilogo><ans:hash></ans:hash></ans:epilogo>" +
            "</ans:mensagemTISS>";
        var bytes = System.Text.Encoding.UTF8.GetBytes(xml);
        var h = TissHashLib.HashTiss(bytes);
        Assert.NotEqual("d41d8cd98f00b204e9800998ecf8427e", h);
    }
}
