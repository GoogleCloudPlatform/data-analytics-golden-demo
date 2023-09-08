namespace RidesharePlus.Models;

public class StreamingDataModel
{
    public int RideCount{ get; set; }
    public float AverageRideDurationMinutes{ get; set; }
    public float AverageTotalAmount{ get; set; }
    public float AverageRideDistance{ get; set; }
    public string? MaxPickupLocationZone{ get; set; }
    public int MaxPickupRideCount{ get; set; }
    public string? MaxDropoffLocationZone{ get; set; }
    public int MaxDropoffRideCount{ get; set; }
}