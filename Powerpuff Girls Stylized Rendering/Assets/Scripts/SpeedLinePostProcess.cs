using UnityEngine;

[ExecuteInEditMode]
[RequireComponent(typeof(Camera))]
public class SpeedLineTransparentPostProcess : MonoBehaviour
{
    public Shader lineShader;
    private Material lineMat;

    public Texture2D noiseTex;
    public Vector2 center = new Vector2(0.5f, 0.5f);
    public float rotateSpeed = 0.2f;
    public float rayMultiply = 6;
    public float rayPower = 1;
    [Range(0, 1)] public float threshold = 0.5f;
    public Color tintColor = Color.white;

    void OnEnable()
    {
        if (lineShader == null)
        {
            enabled = false;
            return;
        }
        lineMat = new Material(lineShader);
        lineMat.hideFlags = HideFlags.HideAndDontSave;
    }

    void OnDisable()
    {
        DestroyImmediate(lineMat);
    }

    void UpdateParameters()
    {
        if (lineMat == null) return;

        lineMat.SetTexture("_NoiseTex", noiseTex);
        lineMat.SetVector("_Center", center);
        lineMat.SetFloat("_RotateSpeed", rotateSpeed);
        lineMat.SetFloat("_RayMultiply", rayMultiply);
        lineMat.SetFloat("_RayPower", rayPower);
        lineMat.SetFloat("_Threshold", threshold);
        lineMat.SetColor("_TintColor", tintColor);
    }

    void OnRenderImage(RenderTexture source, RenderTexture destination)
    {
        if (lineMat == null || noiseTex == null)
        {
            Graphics.Blit(source, destination);
            return;
        }

        UpdateParameters();

        Graphics.Blit(source, destination);
        Graphics.Blit(source, destination, lineMat);
    }
}