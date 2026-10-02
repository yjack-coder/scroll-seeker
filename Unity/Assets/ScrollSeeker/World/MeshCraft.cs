using System.Collections.Generic;
using UnityEngine;

namespace ScrollSeeker
{
    /// <summary>Small reusable mesh recipes for curved roof tiles and the walkable bridge.</summary>
    static class MeshCraft
    {
        public static Mesh Roof(float width, float depth, float rise)
        {
            const int columns = 16, rows = 20;
            var vertices = new List<Vector3>(); var triangles = new List<int>();
            for (int z = 0; z <= rows; z++)
                for (int x = 0; x <= columns; x++)
                {
                    float nx = x * 2f / columns - 1, nz = z * 2f / rows - 1;
                    float elevation = rise * (1 - Mathf.Abs(nz)) + .34f * Mathf.Pow(Mathf.Abs(nz), 5) + .13f * Mathf.Pow(Mathf.Abs(nx), 6);
                    vertices.Add(new Vector3(nx * width * .5f, elevation, nz * depth * .5f));
                }
            for (int z = 0; z < rows; z++)
                for (int x = 0; x < columns; x++)
                {
                    int a = z * (columns + 1) + x, b = a + columns + 1;
                    triangles.Add(a); triangles.Add(b); triangles.Add(a + 1);
                    triangles.Add(a + 1); triangles.Add(b); triangles.Add(b + 1);
                }
            return Finish("Swept village roof", vertices, triangles);
        }

        public static float BridgeHeight(float x) => .06f + Mathf.Sin(Mathf.Clamp01((x + 5.5f) / 11) * Mathf.PI) * 1.05f;
        public static Mesh Bridge()
        {
            var vertices = new List<Vector3>(); var triangles = new List<int>();
            const int steps = 32;
            for (int i = 0; i <= steps; i++)
            {
                float x = Mathf.Lerp(-5.5f, 5.5f, i / (float)steps), y = BridgeHeight(x);
                vertices.Add(new Vector3(x, y, -2)); vertices.Add(new Vector3(x, y, 2));
                vertices.Add(new Vector3(x, y - .32f, -2)); vertices.Add(new Vector3(x, y - .32f, 2));
            }
            for (int i = 0; i < steps; i++)
            {
                int a = i * 4, b = a + 4;
                AddQuad(triangles, a, a + 1, b + 1, b);
                AddQuad(triangles, a + 2, a, b, b + 2);
                AddQuad(triangles, a + 1, a + 3, b + 3, b + 1);
                AddQuad(triangles, a + 3, a + 2, b + 2, b + 3);
            }
            AddQuad(triangles, 0, 2, 3, 1);
            int last = steps * 4; AddQuad(triangles, last, last + 1, last + 3, last + 2);
            return Finish("Arched Willow Bridge", vertices, triangles);
        }

        public static Mesh TaperedCylinder(float bottom, float top, float height, int sides = 12)
        {
            var vertices = new List<Vector3>(); var triangles = new List<int>();
            for (int i = 0; i <= sides; i++)
            {
                float angle = i * Mathf.PI * 2 / sides;
                vertices.Add(new Vector3(Mathf.Cos(angle) * bottom, 0, Mathf.Sin(angle) * bottom));
                vertices.Add(new Vector3(Mathf.Cos(angle) * top, height, Mathf.Sin(angle) * top));
            }
            for (int i = 0; i < sides; i++) AddQuad(triangles, i * 2, i * 2 + 1, i * 2 + 3, i * 2 + 2);
            int center = vertices.Count; vertices.Add(Vector3.zero); vertices.Add(Vector3.up * height);
            for (int i = 0; i < sides; i++)
            {
                // Looking from outside the vessel, the bottom faces down and the lid faces up.
                triangles.Add(center); triangles.Add(i * 2); triangles.Add((i + 1) * 2);
                triangles.Add(center + 1); triangles.Add((i + 1) * 2 + 1); triangles.Add(i * 2 + 1);
            }
            return Finish("Handmade tapered vessel", vertices, triangles);
        }

        static void AddQuad(List<int> t, int a, int b, int c, int d)
        { t.Add(a); t.Add(b); t.Add(c); t.Add(a); t.Add(c); t.Add(d); }
        static Mesh Finish(string name, List<Vector3> v, List<int> t)
        {
            var mesh = new Mesh { name = name };
            mesh.SetVertices(v); mesh.SetTriangles(t, 0); mesh.RecalculateNormals(); mesh.RecalculateBounds();
            return mesh;
        }
    }
}
