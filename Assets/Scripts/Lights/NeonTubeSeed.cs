using UnityEngine;

[RequireComponent(typeof(Renderer))]
public class NeonTubeSeed : MonoBehaviour
{
    [SerializeField] float minSeed = 0f;
    [SerializeField] float maxSeed = 1000f;

    static readonly int SeedID = Shader.PropertyToID("_Seed");

    void Awake()
    {
        var r = GetComponent<Renderer>();
        var mpb = new MaterialPropertyBlock();
        r.GetPropertyBlock(mpb);
        mpb.SetFloat(SeedID, Random.Range(minSeed, maxSeed));
        r.SetPropertyBlock(mpb);
    }
}
