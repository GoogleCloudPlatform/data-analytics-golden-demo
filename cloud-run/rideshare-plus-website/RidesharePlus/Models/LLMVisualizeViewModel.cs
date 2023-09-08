namespace RidesharePlus.Models;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

public class LLMVisualizeViewModel
{

    public LLMVisualizeViewModel()
    {
        this.LookerEmbedUrl = "https://www.google.com";
    }

    [DisplayName("Looker Embed Url")]
    public string? LookerEmbedUrl { get; set; }

}
