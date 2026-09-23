# **Freeform Canvas \- Game Design Document**

Student Name: Charis Chan  
Student ID: 100876550  
Date:September 21, 2026  
Class: CSCI 4160U Game Development  
Repository Link: [https://github.com/Charis-Chan/FreeformCanvas.git](https://github.com/Charis-Chan/FreeformCanvas.git)

## **Description**

A platform fighter with the ability to cancel attacks and dashes. It will contain unique characters with their own gimmicks and abilities, all geared towards extending seamless and creative combos. The goal is to provide as much creative freedom as possible for players to create their own combos and attack strings.

## **Core Gameplay Loop**

### **The Gameplay Loop:** 
The player will play against another player and try to kill the opponent by knocking them off screen while trying to stay alive themselves. Kill other player’s lives before running out of your own lives.

### **Primary Mechanics:** 

- Playable character: jump, double jump, walk, run, normals, strongs, specials, aerials, dashes

### **Secondary Mechanics:** 

- Freeform combo openers:   
  - Stun (I)  
    - Only certain attacks will stun  
    - Base knockback of stun attacks will be halved (maybe quartered)  
      - Opens up combo routes  
    - Stun wears off after 3-5? stun attacks  
      - Start with 5, adjust when balancing/testing  
    - Cooldown of 1-3 seconds to prevent stun locking  
      - Start with 1, adjust when balancing  
  - Slow (II)  
    - Short timer  
      - Active for a certain amount of time (5? sec)  
      - Start with 5, adjust when balancing/testing  
    - Timer cooldown  
      - 3-5 seconds  
        - Start with 3, adjust when balancing/testing  
- Combo extender (mostly grounded \+ aerial)  
  - attack canceling into attacks (turbo)  
  - attacks canceling into dashes

### **Tertiary Mechanics:** 

- Combo extender (strictly aerial):  
  - Platform spawner  
  - Wall jumps  
  - Wall slides slow fall  
- Defensive mechanics: shields/blocks, grabs, parries  
- Training mode

## **MDA Framework**

### **Mechanics:** 

- Refer to the Primary, Secondary, and Tertiary Mechanics above  
- Falling off dies  
- Number of lives  
- Character states \- defining what they can and can’t do at certain times  
- Knockback scales with amount of damage taken

### **Dynamics:** 
- Camping
- stalling
- zoning (no projectiles so may not be possible)
- possibility of too defensive play (waiting around, too afraid to make a mistake)
- chance to ignore off-stage play
- infinites

### **Aesthetics:** 
- more hype combos
- off stage combos/fights
- higher risk-reward factor

## **Player Experience**

### **How should they feel? (Incorporate Leblanc’s Taxonomy of pleasures):**

- Expression  
  - Combos are meant to be as free as possible, letting players form their own combos unique to their playstyle  
- Challenge  
  - Creating own combos, trying to improvise while staying alive  
- Fellowship  
  - Playing with others to increase enjoyment  
  - Rivalry 

## **Game Inspirations:**

* Super Smash Bros series  
* Brawlhalla  
* Rivals of Aether series  
* YOMI Hustle

## **Non-Game Inspirations:**

* Anime

## **Genre:**
Platform Fighter

## **Target Audience (Incorporate Bartle’s Taxonomy):**

- Killers  
  - Compete with other player to be last one standing

## **Progression Over Time:**

- Expected Player Growth  
  - Players get better at their combos  
  - Able to improvise more freely with more experience with the characters

## **Themes:**
Creative harmony

## **Platform & Tools:** 

- PC  
- Odin  
- Raylib  
- Potential Spriting:  
  - Libresprite  
  - Pixel Studio

## **Anything else unusual that needs explaining (if applicable):**  
