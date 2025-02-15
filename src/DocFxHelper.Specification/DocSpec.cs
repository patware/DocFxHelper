using System.Text.Json.Serialization;

namespace DocFxHelper.Specification
{
  [JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]
  [JsonDerivedType(typeof(DocSpecInfo), typeDiscriminator: nameof(Enums.DocSpecType.Info))]
  [JsonDerivedType(typeof(DocSpecAdoWiki), typeDiscriminator: nameof(Enums.DocSpecType.AdoWiki))]
  [JsonDerivedType(typeof(DocSpecDotnetApi), typeDiscriminator: nameof(Enums.DocSpecType.DotnetApi))]
  [JsonDerivedType(typeof(DocSpecRestApi), typeDiscriminator: nameof(Enums.DocSpecType.RestApi))]
  [JsonDerivedType(typeof(DocSpecPowershellModule), typeDiscriminator: nameof(Enums.DocSpecType.PowerShellModule))]
  [JsonDerivedType(typeof(DocSpecConceptual), typeDiscriminator: nameof(Enums.DocSpecType.Conceptual))]
  [JsonDerivedType(typeof(DocSpecDotnetApiYaml), typeDiscriminator: nameof(Enums.DocSpecType.DotnetApiYaml))]
  public class DocSpec
  {

  }
}
