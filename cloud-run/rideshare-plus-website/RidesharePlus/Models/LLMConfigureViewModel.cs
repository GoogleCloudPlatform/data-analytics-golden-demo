namespace RidesharePlus.Models;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;

public class LLMConfigureViewModel
{

    public LLMConfigureViewModel()
    {
        this.LookerEmbedUrl = "https://Replace-Me";
    }

    [DisplayName("Looker Embed Url")]
    public string? LookerEmbedUrl { get; set; }

    public string? ProjectId { get; set; }

    public string? DatasetName { get; set; }

    public string? LookerCustomerReview { get; set; }

    public string? LookerCustomer { get; set; }

    public string? LookerDriver { get; set; }

}
