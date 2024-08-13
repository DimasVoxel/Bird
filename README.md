# Teardown Bird Mod


https://github.com/user-attachments/assets/f27de499-2dc5-425c-af4a-e8e007eb9f41


---

**Birds!** A new animal joins the scenery.

This mod introduces **19 unique birds** that will roam your world, totaling **38 wings**! Although it's still in its early stages, reaching this point has been the most challenging part of the journey.

### Features:
- **Bird Behavior:** Birds can roam your world, peck the ground, and most importantly, **fly**.
- **Custom Pathfinder:** At the heart of this mod is a custom pathfinder that enables birds to fly without crashing (mostly).
- **Navigation Data:** When playing on a new map, the mod will build navigation data, which may take about 30 seconds. Subsequent plays on the same map will load faster.

### Contest Submission:
This mod was submitted for the **38 Mod Contest** and won **second place**!

---

### Custom scanner ###

This mod required the development of a custom terrain scanner to create an accurate navigation grid for the birds. The process unfolds in three key steps:

1. **Initial Scan with an Octree:** The first step involves scanning the map to determine accessible areas using an octree. This method recursively examines the entire map. Thanks to the nature of octrees, I was able to optimize the runtime by efficiently skipping over large, empty spaces.
2. **Grid Creation:** Once the accessible areas are identified, the next step is to generate a navigation grid that the birds will use to explore the environment.
3. **Neighbor Detection:** The final step is to establish connections between walkable grids, efficiently identifying neighbors to minimize computational steps.

This custom scanning process ensures that the birds can navigate the world smoothly and realistically, even on complex terrains.

https://github.com/user-attachments/assets/d41f2fbb-94c0-4c62-93a7-298908f55837


### Custom Path finding and navigation ###

For navigation, the **A-Star algorithm** was chosen for its speed and efficiency. It excels at handling complex terrain, ensuring that birds can quickly and smoothly find their way across the environment.

https://github.com/user-attachments/assets/654fb903-fe9b-4094-84dd-2ee6af8472bf

---

Additionally, the algorithm was finely tuned to reflect realistic bird flight behavior. This allows the birds to navigate with a natural flow, mimicking how they would adjust their flight paths in the real world.

https://github.com/user-attachments/assets/31f87d31-0777-4fc2-a427-fcd920b91980
