using System.Text.Json.Serialization;

namespace DocFxHelper.Specification
{
  [JsonPolymorphic(TypeDiscriminatorPropertyName = "type")]
  [JsonDerivedType(typeof(DocSpecMain), typeDiscriminator: "Main")]
  [JsonDerivedType(typeof(DocSpecAdoWiki), typeDiscriminator: "AdoWiki")]
  [JsonDerivedType(typeof(DocSpecPowershellModule), typeDiscriminator: "PowerShellModule")]
  public class DocSpec
  {

  }
}
