<#include "procedures.java.ftl">
@Mod.EventBusSubscriber public class ${name}Procedure {
  <#-- EventType #-->
  private static final String NONE = "NONE";
  private static final String RENDER_FOG = "RENDER_FOG";
  private static final String COMPUTE_FOG_COLOR = "COMPUTE_FOG_COLOR";
  private static final String RENDER_SKY = "RENDER_SKY";
  private static final String RENDER_CLOUDS = "RENDER_CLOUDS";
  private static final String RENDER_WEATHER = "RENDER_WEATHER";
  <#-- Direction #-->
  private static final String TOP = "TOP";
  private static final String BOTTOM = "BOTTOM";
  <#-- Color Component #-->
  private static final String RED = "RED";
  private static final String GREEN = "GREEN";
  private static final String BLUE = "BLUE";
  private static final String ALPHA = "ALPHA";
  <#-- Color Model #-->
  private static final String HSBA = "HSBA";
  private static final String RGBA = "RGBA";
  <#-- Parameter Managers #-->
  private static Map<String, Object> renderingManager = new HashMap<String, Object>() {
    {
      put("RenderFog", null);
      put("ComputeFogColor", null);
      put("Camera", null);
      put("PoseStack", null);
      put("Matrix4f", null);
      put("PartialTick", null);
      put("DefaultCloudStatus", null);
    }
  };

  private static String eventType = NONE;
  private static int ticks = 0;

  private static float[] RGBAToFloat(double red, double green, double blue, double alpha) {
    float[] result = new float[4];

    if (red < 0.0D) {
      red = 0.0D;
    }
    if (red > 255.0D) {
      red = 255.0D;
    }
    if (green < 0.0D) {
      green = 0.0D;
    }
    if (green > 255.0D) {
      green = 255.0D;
    }
    if (blue < 0.0D) {
      blue = 0.0D;
    }
    if (blue > 255.0D) {
      blue = 255.0D;
    }
    if (alpha < 0.0D) {
      alpha = 0.0D;
    }
    if (alpha > 255.0D) {
      alpha = 255.0D;
    }

    result[0] = ((float) red) / 255.0F;
    result[1] = ((float) green) / 255.0F;
    result[2] = ((float) blue) / 255.0F;
    result[3] = ((float) alpha) / 255.0F;

    return result;
  }

  private static float[] HSBAToRGBA(double hue, double saturation, double brightness, double alpha) {
    float float0 = 0.0F;
    float float1 = 0.0F;
    float float2 = 0.0F;
    float[] floats = new float[3];
    float[] result = new float[4];

    saturation /= 100.0D;
    brightness /= 100.0D;
    alpha /= 100.0D;

    if (hue < 0.0D) {
      hue = hue % 360 + 360;
    }
    if (hue >= 360.0D) {
      hue %= 360;
    }
    if (saturation < 0.0D) {
      saturation = 0.0D;
    }
    if (saturation > 1.0D) {
      saturation = 1.0D;
    }
    if (brightness < 0.0D) {
      brightness = 0.0D;
    }
    if (brightness > 1.0D) {
      brightness = 1.0D;
    }
    if (alpha < 0.0D) {
      alpha = 0.0D;
    }
    if (alpha > 1.0D) {
      alpha = 1.0D;
    }

    float0 = (float) (brightness * saturation);
    float1 = float0 * (1.0F - Math.abs((((float) hue) / 60.0F) % 2.0F - 1.0F));
    float2 = ((float) brightness) - float0;

    if (0.0D <= hue && hue < 60.0D) {
      floats[0] = float0;
      floats[1] = float1;
      floats[2] = 0.0F;
    } else if (60.0D <= hue && hue < 120.0D) {
      floats[0] = float1;
      floats[1] = float0;
      floats[2] = 0.0F;
    } else if (120.0D <= hue && hue < 180.0D) {
      floats[0] = 0.0F;
      floats[1] = float0;
      floats[2] = float1;
    } else if(180.0D <= hue && hue < 240.0D) {
      floats[0] = 0.0F;
      floats[1] = float1;
      floats[2] = float0;
    } else if(240.0D <= hue && hue < 300.0D) {
      floats[0] = float1;
      floats[1] = 0.0F;
      floats[2] = float0;
    } else if(300.0D <= hue && hue < 360.0D) {
      floats[0] = float0;
      floats[1] = 0.0F;
      floats[2] = float1;
    }

    result[0] = (floats[0] + float2);
    result[1] = (floats[1] + float2);
    result[2] = (floats[2] + float2);
    result[3] = ((float) alpha);

    return result;
  }

  private static int[] getTextureSize(String id, String path) {
    ResourceLocation textureLocation = new ResourceLocation(id, path);
    int[] result = new int[2];

    try {
      InputStream stream = Minecraft.getInstance().getResourceManager().open(textureLocation);
      NativeImage image = NativeImage.read(stream);
      result[0] = image.getWidth();
      result[1] = image.getHeight();
      image.close();
    } catch(Exception e) {
      result[0] = 0;
      result[1] = 0;
    } 

    return result;
  }

  @OnlyIn(Dist.CLIENT)
  private static void drawDefaultElements(boolean topSkyFlag, boolean bottomSkyFlag, boolean starFlag, boolean sunlightFlag, boolean sunFlag, boolean moonFlag, boolean cloudFlag, boolean endSkyFlag) {
    Minecraft minecraft = Minecraft.getInstance();
    ClientLevel clientLevel = minecraft.level;

    if (clientLevel.effects().skyType() == DimensionSpecialEffects.SkyType.END) {
      if (eventType.equals(RENDER_SKY)) {
        if (endSkyFlag) {
          drawTextureSky("minecraft", "textures/environment/end_sky.png");
        } 
      }
    } else if (clientLevel.effects().skyType() == DimensionSpecialEffects.SkyType.NORMAL) {
      if (eventType.equals(RENDER_SKY)) {
        if (topSkyFlag) {
          double skyRed = getSkyColor(RED);
          double skyGreen = getSkyColor(GREEN);
          double skyBlue = getSkyColor(BLUE);
          double skyAlpha = getSkyColor(ALPHA);
          drawSky(TOP, skyRed, skyGreen, skyBlue, skyAlpha, RGBA);
        }

        if (bottomSkyFlag) {
          float partialTick = (Float) renderingManager.get("PartialTick");
          double eyeHeight = minecraft.player.getEyePosition(partialTick).y();
          double seaLevel = clientLevel.getLevelData().getHorizonHeight(clientLevel);
          if (eyeHeight < seaLevel) {
            drawSky(BOTTOM, 0.0D, 0.0D, 0.0D, 255.0D, RGBA);
          }
        }

        if (starFlag) {
          double starRed = getStarColor(RED);
          double starGreen = getStarColor(GREEN);
          double starBlue = getStarColor(BLUE);
          double starAlpha = getStarColor(ALPHA);
          drawStar(1500.0D, 10842.0D, starRed, starGreen, starBlue, starAlpha, RGBA);
        }

        if (sunlightFlag) {
          double sunlightRed = getSunlightColor(RED);
          double sunlightGreen = getSunlightColor(GREEN);
          double sunlightBlue = getSunlightColor(BLUE);
          double sunlightAlpha = getSunlightColor(ALPHA);
          drawSunlight(sunlightRed, sunlightGreen, sunlightBlue, sunlightAlpha, RGBA);
        }

        if (sunFlag || moonFlag) {
          double dayTime = clientLevel.getLevelData().getDayTime();
          if (sunFlag) {
            drawTexture("minecraft", "textures/environment/sun.png", -90.0D, dayTime * -0.015D, 0.0D, 30.0D);
          }
          if (moonFlag) {
            drawTexture("minecraft", "textures/environment/moon_phases.png", 90.0D, dayTime * 0.015D, 0.0D, 20.0D);
          }
        }
      }

      if (eventType.equals(RENDER_CLOUDS)) {
        if (cloudFlag) {
          double cloudHeight = getCloudHeight();
          drawClouds(cloudHeight, -1.0D, 0.0D, "minecraft", "textures/environment/clouds.png");
        }
      }
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static void drawSky(String direction, double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      float[] skyColor = new float[4];
      if (colorModel.equals(RGBA)) {
        skyColor = RGBAToFloat(color0, color1, color2, color3);
      } else if (colorModel.equals(HSBA)) {
        skyColor = HSBAToRGBA(color0, color1, color2, color3);
      }

      if (skyColor[3] > 0.0F) {
        PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
        Matrix4f matrix4f = (Matrix4f) renderingManager.get("Matrix4f");
        VertexBuffer skyBuffer = new VertexBuffer();

        RenderSystem.disableTexture();
        RenderSystem.depthMask(false);
	      RenderSystem.enableBlend();
	      RenderSystem.defaultBlendFunc();
        RenderSystem.setShaderColor(skyColor[0], skyColor[1], skyColor[2], skyColor[3]);
        RenderSystem.setShader(GameRenderer::getPositionShader);

        BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
        float vertex0 = direction.equals(TOP) ? 16.0F : -16.0F;
		    float vertex1 = direction.equals(TOP) ? 512.0F : -512.0F;

		    bufferBuilder.begin(VertexFormat.Mode.TRIANGLE_FAN, DefaultVertexFormat.POSITION);
		    bufferBuilder.vertex(0.0D, (double) vertex0, 0.0D).endVertex();
		    for (int i = -180; i <= 180; i += 45) {
			    bufferBuilder.vertex((double) vertex1 * Mth.cos((float) i * ((float) Math.PI / 180F)), 0.0D, (double) (512.0F * Mth.sin((float) i * ((float) Math.PI / 180F)))).endVertex();
		    }
		    BufferBuilder.RenderedBuffer renderedBuffer = bufferBuilder.end();
        
        poseStack.pushPose();
        skyBuffer.bind();
	      skyBuffer.upload(renderedBuffer);
        skyBuffer.drawWithShader(poseStack.last().pose(), matrix4f, RenderSystem.getShader());
        skyBuffer.close();
        poseStack.popPose();
        bufferBuilder.discard();

        RenderSystem.disableBlend();
        RenderSystem.depthMask(true);
        RenderSystem.enableTexture();
      }
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static void drawTextureSky(String id, String path) {
    if (eventType.equals(RENDER_SKY)) {
      Minecraft minecraft = Minecraft.getInstance();
      if (!minecraft.gui.getBossOverlay().shouldCreateWorldFog()) {
        PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
        float skyRed = 1.0F;
        float skyGreen = 1.0F;
        float skyBlue = 1.0F;
        float skyAlpha = 1.0F;
        float uv0 = 0.0F;
        float uv1 = 0.0F;
        float uv2 = 1.0F;
        float uv3 = 1.0F;
        if (id.equals("minecraft") && path.equals("textures/environment/end_sky.png")) {
          skyRed = 0.15686274509F;
          skyGreen = 0.15686274509F;
          skyBlue = 0.15686274509F;
          skyAlpha = 1.0F;
          uv0 = 0.0F;
          uv1 = 0.0F;
          uv2 = 16.0F;
          uv3 = 16.0F;
        }

		    RenderSystem.depthMask(false);
		    RenderSystem.enableBlend();
		    RenderSystem.defaultBlendFunc();
		    RenderSystem.setShader(GameRenderer::getPositionTexColorShader);
        RenderSystem.setShaderColor(1.0F, 1.0F, 1.0F, 1.0F);
		    RenderSystem.setShaderTexture(0, new ResourceLocation(id, path));

		    BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
		    for (int i = 0; i < 6; i++) {
			    poseStack.pushPose();
			    if (i == 1) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
			    }
			    if (i == 2) {
            poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-90.0F));
			    }
			    if (i == 3) {
            poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-180.0F));
			    }
			    if (i == 4) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-270.0F));
			    }
			    if (i == 5) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(180.0F));
            poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			    }
			    Matrix4f matrix4f = poseStack.last().pose();
			    bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION_TEX_COLOR);
			    bufferBuilder.vertex(matrix4f, -100.0F, -100.0F, -100.0F).uv(uv0, uv1).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(matrix4f, -100.0F, -100.0F, 100.0F).uv(uv1, uv2).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(matrix4f, 100.0F, -100.0F, 100.0F).uv(uv2, uv3).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(matrix4f, 100.0F, -100.0F, -100.0F).uv(uv3, uv0).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    BufferUploader.drawWithShader(bufferBuilder.end());
			    poseStack.popPose();
		    }
        bufferBuilder.discard();

		    RenderSystem.disableBlend();
        RenderSystem.depthMask(true);
      }
    }
  }
  
  @OnlyIn(Dist.CLIENT)
	private static void drawClouds(double height, double vx0, double vz0, String id, String path) {
    if (eventType.equals(RENDER_CLOUDS)) {
      Minecraft minecraft = Minecraft.getInstance();
      ClientLevel clientLevel = minecraft.level;
      float partialTick = (Float) renderingManager.get("PartialTick");
      CloudStatus cloudsType = minecraft.options.getCloudsType();
      float cloudHeight = (float) height;

      int[] textureSize = getTextureSize(id, path);
      int size = Math.min(textureSize[0], textureSize[1]);

      float[] cloudColor = new float[4];
      Vec3 colorFactor = clientLevel.getCloudColor(partialTick);
      cloudColor[0] = (float) colorFactor.x();
      cloudColor[1] = (float) colorFactor.y();
      cloudColor[2] = (float) colorFactor.z();
      if (id.equals("minecraft") && path.equals("textures/environment/clouds.png")) {
        cloudColor[3] = 0.8F;
      } else {
        cloudColor[3] = 1.0F;
      }

      if (cloudsType != CloudStatus.OFF && !Float.isNaN(cloudHeight) && size > 0 && cloudColor[3] > 0.0F) {
        Vec3 cameraPos = ((Camera) renderingManager.get("Camera")).getPosition();
        Matrix4f matrix4f = (Matrix4f) renderingManager.get("Matrix4f");
				PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
				double cameraX = cameraPos.x();
				double cameraY = cameraPos.y();
				double cameraZ = cameraPos.z();
				VertexBuffer cloudBuffer = new VertexBuffer();

        RenderSystem.enableTexture();
				RenderSystem.depthMask(true);
				RenderSystem.enableBlend();
				RenderSystem.enableDepthTest();
				RenderSystem.blendFuncSeparate(GlStateManager.SourceFactor.SRC_ALPHA, GlStateManager.DestFactor.ONE_MINUS_SRC_ALPHA,
						GlStateManager.SourceFactor.ONE, GlStateManager.DestFactor.ONE_MINUS_SRC_ALPHA);
				RenderSystem.setShader(GameRenderer::getPositionTexColorNormalShader);
				RenderSystem.setShaderTexture(0, new ResourceLocation(id, path));
				RenderSystem.disableCull();

        double vectorFactor = ((float) ticks + partialTick) * 0.03D;
				double vx1 = (cameraX - (vx0 * vectorFactor)) / 12.0D;
				double vy1 = cloudHeight - cameraY + 0.33D;
				double vz1 = (cameraZ - (vz0 * vectorFactor)) / 12.0D + 0.33D;
				vx1 -= Mth.floor(vx1 / 2048.0D) * 2048D;
				vz1 -= Mth.floor(vz1 / 2048.0D) * 2048D;
				double vx2 = vx1 - Mth.floor(vx1);
				double vy2 = (vy1 / 4.0D - (double) Mth.floor(vy1 / 4.0D)) * 4.0D;
				double vz2 = vz1 - Mth.floor(vz1);
        float factor = 1.0F / size; 
				float u = Mth.floor(vx1) * factor;
				float v = Mth.floor(vz1) * factor;
				float cloudRed0 = cloudColor[0];
				float cloudGreen0 = cloudColor[1];
				float cloudBlue0 = cloudColor[2];
        float cloudAlpha0 = cloudColor[3];
				float cloudRed1 = cloudColor[0] * 0.9F;
				float cloudGreen1 = cloudColor[1] * 0.9F;
				float cloudBlue1 = cloudColor[2] * 0.9F;
				float cloudRed2 = cloudColor[0] * 0.8F;
				float cloudGreen2 = cloudColor[1] * 0.8F;
				float cloudBlue2 = cloudColor[2] * 0.8F;
				float cloudRed3 = cloudColor[0] * 0.7F;
				float cloudGreen3 = cloudColor[1] * 0.7F;
				float cloudBlue3 = cloudColor[2] * 0.7F;

        BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
				bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION_TEX_COLOR_NORMAL);

        double vy3 = Math.floor(vy1 / 4.0D) * 4.0D;
        if (cloudsType == CloudStatus.FANCY) {
					for (int i = -3; i <= 4; i++) {
						for (int j = -3; j <= 4; j++) {
							double vx3 = i * 8.0D;
							double vz3 = j * 8.0D;
							if (vy3 > -5.0D) {
								bufferBuilder.vertex(vx3 + 0.0D, vy3, vz3 + 8.0D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed3, cloudGreen3, cloudBlue3, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 8.0D, vy3, vz3 + 8.0D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed3, cloudGreen3, cloudBlue3, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 8.0D, vy3, vz3 + 0.0D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed3, cloudGreen3, cloudBlue3, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 0.0D, vy3, vz3 + 0.0D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed3, cloudGreen3, cloudBlue3, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
							}
							if (vy3 <= 5.0D) {
								bufferBuilder.vertex(vx3 + 0.0D, vy3 + 4.0D - 9.765625E-4D, vz3 + 8.0D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, 1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 8.0D, vy3 + 4.0D - 9.765625E-4D, vz3 + 8.0D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, 1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 8.0D, vy3 + 4.0D - 9.765625E-4D, vz3 + 0.0D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, 1.0F, 0.0F).endVertex();
								bufferBuilder.vertex(vx3 + 0.0D, vy3 + 4.0D - 9.765625E-4D, vz3 + 0.0D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, 1.0F, 0.0F).endVertex();
							}
							if (i > -1) {
								for (int k = 0; k < 8; k++) {
									bufferBuilder.vertex(vx3 + k, vy3 + 0.0D, vz3 + 8.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(-1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k, vy3 + 4.0D, vz3 + 8.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(-1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k, vy3 + 4.0D, vz3 + 0.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(-1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k, vy3 + 0.0D, vz3 + 0.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(-1.0F, 0.0F, 0.0F).endVertex();
								}
							}
							if (i <= 1) {
								for (int k = 0; k < 8; k++) {
									bufferBuilder.vertex(vx3 + k + 1.0D - 9.765625E-4D, vy3 + 0.0D, vz3 + 8.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k + 1.0D - 9.765625E-4D, vy3 + 4.0D, vz3 + 8.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 8.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k + 1.0D - 9.765625E-4D, vy3 + 4.0D, vz3 + 0.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(1.0F, 0.0F, 0.0F).endVertex();
									bufferBuilder.vertex(vx3 + k + 1.0D - 9.765625E-4D, vy3 + 0.0D, vz3 + 0.0D).uv(((float) vx3 + k + 0.5F) * factor + u, ((float) vz3 + 0.0F) * factor + v).color(cloudRed1, cloudGreen1, cloudBlue1, cloudAlpha0).normal(1.0F, 0.0F, 0.0F).endVertex();
								}
							}
							if (j > -1) {
								for (int k = 0; k < 8; k++) {
									bufferBuilder.vertex(vx3 + 0.0D, vy3 + 4.0D, vz3 + k).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, -1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 8.0D, vy3 + 4.0D, vz3 + k).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, -1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 8.0D, vy3 + 0.0D, vz3 + k).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, -1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 0.0D, vy3 + 0.0D, vz3 + k).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, -1.0F).endVertex();
								}
							}
							if (j <= 1) {
								for (int k = 0; k < 8; k++) {
									bufferBuilder.vertex(vx3 + 0.0D, vy3 + 4.0D, vz3 + k + 1.0D - 9.765625E-4D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, 1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 8.0D, vy3 + 4.0D, vz3 + k + 1.0D - 9.765625E-4D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, 1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 8.0D, vy3 + 0.0D, vz3 + k + 1.0D - 9.765625E-4D).uv(((float) vx3 + 8.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, 1.0F).endVertex();
									bufferBuilder.vertex(vx3 + 0.0D, vy3 + 0.0D, vz3 + k + 1.0D - 9.765625E-4D).uv(((float) vx3 + 0.0F) * factor + u, ((float) vz3 + k + 0.5F) * factor + v).color(cloudRed2, cloudGreen2, cloudBlue2, cloudAlpha0).normal(0.0F, 0.0F, 1.0F).endVertex();
								}
							}
						}
					}
				} else {
					for (int i = -32; i < 32; i += 32) {
						for (int j = -32; j < 32; j += 32) {
							bufferBuilder.vertex(i + 0.0D, vy3, j + 32.0D).uv((i + 0.0F) * factor + u, (j + 32.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
							bufferBuilder.vertex(i + 32.0D, vy3, j + 32.0D).uv((i + 32.0F) * factor + u, (j + 32.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
							bufferBuilder.vertex(i + 32.0D, vy3, j + 0.0D).uv((i + 32.0F) * factor + u, (j + 0.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
							bufferBuilder.vertex(i + 0.0D, vy3, j + 0.0D).uv((i + 0.0F) * factor + u, (j + 0.0F) * factor + v).color(cloudRed0, cloudGreen0, cloudBlue0, cloudAlpha0).normal(0.0F, -1.0F, 0.0F).endVertex();
						}
					}
				}

				BufferBuilder.RenderedBuffer renderedBuffer = bufferBuilder.end();

        cloudBuffer.bind();
				cloudBuffer.upload(renderedBuffer);
				FogRenderer.levelFogColor();
				poseStack.pushPose();
				poseStack.scale(12.0F, 1.0F, 12.0F);
				poseStack.translate(-vx2, vy2, -vz2);
        if (cloudsType == CloudStatus.FANCY) {
          RenderSystem.colorMask(false, false, false, false);
          cloudBuffer.drawWithShader(poseStack.last().pose(), matrix4f, RenderSystem.getShader());
          RenderSystem.colorMask(true, true, true, true);
          cloudBuffer.drawWithShader(poseStack.last().pose(), matrix4f, RenderSystem.getShader());
        } else {
          RenderSystem.colorMask(true, true, true, true);
          cloudBuffer.drawWithShader(poseStack.last().pose(), matrix4f, RenderSystem.getShader());
        }
        cloudBuffer.close();
				poseStack.popPose();
				bufferBuilder.discard();
				
				RenderSystem.enableCull();
				RenderSystem.disableBlend();
				RenderSystem.depthMask(false);
				RenderSystem.disableTexture();
      }
    }
  }


  @OnlyIn(Dist.CLIENT)
  private static void drawStar(double amount, double seed, double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      int starAmount = (int) amount;
      
      float[] starColor = new float[4];
      if (colorModel.equals(RGBA)) {
        starColor = RGBAToFloat(color0, color1, color2, color3);
      } else if (colorModel.equals(HSBA)) {
        starColor = HSBAToRGBA(color0, color1, color2, color3);
      }

      if (starAmount > 0 && starColor[3] > 0.0F) {
        PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
		    Matrix4f matrix4f = (Matrix4f) renderingManager.get("Matrix4f");
        VertexBuffer starBuffer = new VertexBuffer();
        Random random = new Random((long) seed);

        FogRenderer.setupNoFog();
        RenderSystem.disableTexture();
			  RenderSystem.depthMask(false);
			  RenderSystem.enableBlend();
			  RenderSystem.defaultBlendFunc();
			  RenderSystem.setShaderColor(starColor[0], starColor[1], starColor[2], starColor[3]);
			  RenderSystem.setShader(GameRenderer::getPositionShader);
      
        BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
			  bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION);
			  for (int i = 0; i < starAmount; i++) {
				  double starX0 = (double) (random.nextFloat() * 2.0F - 1.0F);
				  double starY0 = (double) (random.nextFloat() * 2.0F - 1.0F);
				  double starZ0 = (double) (random.nextFloat() * 2.0F - 1.0F);
				  double distance = starX0 * starX0 + starY0 * starY0 + starZ0 * starZ0;
				  if (distance < 1.0D && distance > 0.01D) {
					  distance = 1.0D / Math.sqrt(distance);
					  starX0 *= distance;
					  starY0 *= distance;
					  starZ0 *= distance;
					  double starX1 = starX0 * 100.0D;
					  double starY1 = starY0 * 100.0D;
					  double starZ1 = starZ0 * 100.0D;
					  double radian0 = Math.atan2(starX0, starZ0);
					  double sin0 = Math.sin(radian0);
					  double cos0 = Math.cos(radian0);
					  double radian1 = Math.atan2(Math.sqrt(starX0 * starX0 + starZ0 * starZ0), starY0);
					  double sin1 = Math.sin(radian1);
					  double cos1 = Math.cos(radian1);
					  double radian2 = random.nextDouble() * Math.PI * 2.0D;
					  double sin2 = Math.sin(radian2);
					  double cos2 = Math.cos(radian2);
            double double0 = (double) (0.15F + random.nextFloat() * 0.1F);
					  for (int j = 0; j < 4; j++) {
						  double double1 = (double) ((j & 2) - 1) * double0;
						  double double2 = (double) ((j + 1 & 2) - 1) * double0;
						  double double3 = double1 * cos2 - double2 * sin2;
						  double double4 = double2 * cos2 + double1 * sin2;
						  double double5 = double3 * sin1;
						  double double6 = double3 * -cos1;
						  double double7 = double6 * sin0 - double4 * cos0;
						  double double8 = double4 * sin0 + double6 * cos0;
						  bufferBuilder.vertex(starX1 + double7, starY1 + double5, starZ1 + double8).endVertex();
					  }
				  }
			  }
        BufferBuilder.RenderedBuffer renderedBuffer = bufferBuilder.end();
			  poseStack.pushPose();
        starBuffer.bind();
        starBuffer.upload(renderedBuffer);
			  starBuffer.drawWithShader(poseStack.last().pose(), matrix4f, GameRenderer.getPositionShader());
        starBuffer.close();
			  poseStack.popPose();
        bufferBuilder.discard();

			  RenderSystem.disableBlend();
			  RenderSystem.depthMask(true);
			  RenderSystem.enableTexture();
      }
    }
  }
  
  @OnlyIn(Dist.CLIENT)
  private static void drawSunlight(double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      float[] sunlightColor = new float[4];
      if (colorModel.equals(RGBA)) {
        sunlightColor = RGBAToFloat(color0, color1, color2, color3);
      } else if (colorModel.equals(HSBA)) {
        sunlightColor = HSBAToRGBA(color0, color1, color2, color3);
      }

      if (sunlightColor[3] > 0.0F) {
        Minecraft minecraft = Minecraft.getInstance();
		    ClientLevel clientLevel = minecraft.level;
        PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
        float partialTick = (Float) renderingManager.get("PartialTick");
        float sunlightRed = sunlightColor[0];
			  float sunlightGreen = sunlightColor[1];
			  float sunlightBlue = sunlightColor[2];
		    float sunlightAlpha = sunlightColor[3];
        float pitch = Mth.sin(clientLevel.getSunAngle(partialTick)) < 0.0F ? 180.0F : 0.0F;

        RenderSystem.disableTexture();
        RenderSystem.depthMask(false);
			  RenderSystem.enableBlend();
		    RenderSystem.defaultBlendFunc();
        RenderSystem.setShaderColor(1.0F, 1.0F, 1.0F, 1.0F);
			  RenderSystem.setShader(GameRenderer::getPositionColorShader);

        BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
			  poseStack.pushPose();
        poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
        poseStack.mulPose(Vector3f.ZP.rotationDegrees(90.0F));
	      poseStack.mulPose(Vector3f.ZP.rotationDegrees(pitch));
			  Matrix4f matrix4f = poseStack.last().pose();
			  bufferBuilder.begin(VertexFormat.Mode.TRIANGLE_FAN, DefaultVertexFormat.POSITION_COLOR);
			  bufferBuilder.vertex(matrix4f, 0.0F, 100.0F, 0.0F).color(sunlightRed, sunlightGreen, sunlightBlue, sunlightAlpha).endVertex();
			  for (int i = 0; i <= 16; ++i) {
			    float radian = (float) i * ((float) Math.PI * 2F) / 16.0F;
			    float sin = Mth.sin(radian);
			    float cos = Mth.cos(radian);
			    bufferBuilder.vertex(matrix4f, sin * 120.0F, cos * 120.0F, -cos * 40.0F * sunlightAlpha).color(sunlightRed, sunlightGreen, sunlightBlue, 0.0F).endVertex();
			  }
			  poseStack.popPose();
        BufferUploader.drawWithShader(bufferBuilder.end());
        bufferBuilder.discard();

        RenderSystem.disableBlend();
        RenderSystem.depthMask(true);
        RenderSystem.enableTexture();
      }
    }
  }
  
  @OnlyIn(Dist.CLIENT)
  private static void drawTexture(String id, String path, double yaw, double pitch, double roll, double size) {
    if (eventType.equals(RENDER_SKY)) {
      Minecraft minecraft = Minecraft.getInstance();
		  ClientLevel clientLevel = minecraft.level;
      PoseStack poseStack = (PoseStack) renderingManager.get("PoseStack");
      float partialTick = (Float) renderingManager.get("PartialTick");
      float pos = (float) size;
      float uv0 = 1.0F;
      float uv1 = 1.0F;
      float uv2 = 0.0F;
      float uv3 = 0.0F;
      float alpha = 1.0F - clientLevel.getRainLevel(partialTick);
      boolean isDefaultSun = false;
      boolean isDefaultMoon = false;

      if (id.equals("minecraft") && path.equals("textures/environment/sun.png")) {
        isDefaultSun = true;
      } else if (id.equals("minecraft") && path.equals("textures/environment/moon_phases.png")) {
        int phase = clientLevel.getMoonPhase();
        int int0 = phase % 4;
        int int1 = phase / 4 % 2;
        uv0 = (float) (int0 + 0) / 4.0F;
        uv1 = (float) (int1 + 0) / 2.0F;
        uv2 = (float) (int0 + 1) / 4.0F;
        uv3 = (float) (int1 + 1) / 2.0F;
        isDefaultMoon = true;
      }

      RenderSystem.enableBlend();
	    RenderSystem.defaultBlendFunc();
      if (isDefaultSun || isDefaultMoon) {
        RenderSystem.blendFuncSeparate(GlStateManager.SourceFactor.SRC_ALPHA, GlStateManager.DestFactor.ONE, GlStateManager.SourceFactor.ONE, GlStateManager.DestFactor.ZERO);
      }
      RenderSystem.enableTexture();
      RenderSystem.setShaderColor(1.0F, 1.0F, 1.0F, alpha);
      RenderSystem.setShader(GameRenderer::getPositionTexShader);
	    RenderSystem.setShaderTexture(0, new ResourceLocation(id, path));

      poseStack.pushPose();
	    poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
      poseStack.mulPose(Vector3f.ZP.rotationDegrees((float) yaw));
	    poseStack.mulPose(Vector3f.XP.rotationDegrees((float) pitch));
	    poseStack.mulPose(Vector3f.YP.rotationDegrees((float) roll));
      Matrix4f matrix4f = poseStack.last().pose();
      BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
      bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION_TEX);
	    bufferBuilder.vertex(matrix4f, -pos, 100.0F, -pos).uv(uv2, uv3).endVertex();
      bufferBuilder.vertex(matrix4f, pos, 100.0F, -pos).uv(uv0, uv3).endVertex();
      bufferBuilder.vertex(matrix4f, pos, 100.0F, pos).uv(uv0, uv1).endVertex();
      bufferBuilder.vertex(matrix4f, -pos, 100.0F, pos).uv(uv2, uv1).endVertex();
      poseStack.popPose();
	    BufferUploader.drawWithShader(bufferBuilder.end());
      bufferBuilder.discard();

	    RenderSystem.disableTexture();
	    RenderSystem.disableBlend();
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static void setFogColor(double color0, double color1, double color2, double color3, String component) {
    if (eventType.equals(COMPUTE_FOG_COLOR) || eventType.equals(RENDER_SKY)) {
      float[] fogColor = new float[4];
      if (component.equals(RGBA)) {
        fogColor = RGBAToFloat(color0, color1, color2, color3);
      } else if (component.equals(HSBA)) {
        fogColor = HSBAToRGBA(color0, color1, color2, color3);
      }

      if (eventType.equals(COMPUTE_FOG_COLOR)) {
        ViewportEvent.ComputeFogColor event = (ViewportEvent.ComputeFogColor) renderingManager.get("ComputeFogColor");
        event.setRed(fogColor[0]);
        event.setGreen(fogColor[1]);
        event.setBlue(fogColor[2]);
      } else if (eventType.equals(RENDER_SKY)) {
        RenderSystem.setShaderFogColor(fogColor[0], fogColor[1], fogColor[2], fogColor[3]);
      }
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static void setFogDistance(double start, double end) {
    if (eventType.equals(RENDER_FOG)) {
      ViewportEvent.RenderFog event = (ViewportEvent.RenderFog) renderingManager.get("RenderFog");
      event.setNearPlaneDistance((float) start);
      event.setFarPlaneDistance((float) end);
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static void setFogShape(FogShape shape) {
    if (eventType.equals(RENDER_FOG)) {
      ViewportEvent.RenderFog event = (ViewportEvent.RenderFog) renderingManager.get("RenderFog");
      event.setFogShape(shape);
    }
  }

  @OnlyIn(Dist.CLIENT)
  private static double getFogEndDistance() {
    double result = 0.0D;
    result = RenderSystem.getShaderFogEnd();
    return result;
  }

  @OnlyIn(Dist.CLIENT)
  private static double getFogStartDistance() {
    double result = 0.0D;
    result = RenderSystem.getShaderFogStart();
    return result;
  }

  @OnlyIn(Dist.CLIENT)
  private static double getFogColor(String component) {
    float[] fogColor = RenderSystem.getShaderFogColor();
    double result = 0.0D;

    if (component.equals(RED)) {
      result = fogColor[0] * 255.0D;
    } else if (component.equals(GREEN)) {
      result = fogColor[1] * 255.0D;
    } else if (component.equals(BLUE)) {
      result = fogColor[2] * 255.0D;
    }

    return result;
  }
  
  @OnlyIn(Dist.CLIENT)
  private static double getSkyColor(String component) {
    Minecraft minecraft = Minecraft.getInstance();
		ClientLevel clientLevel = minecraft.level;
    Vec3 skyColor = clientLevel.getSkyColor(((Camera) renderingManager.get("Camera")).getPosition(), (Float) renderingManager.get("PartialTick"));
    double result = 0.0D;

    if (component.equals(RED)) {
      result = skyColor.x() * 255.0D;
    } else if (component.equals(GREEN)) {
      result = skyColor.y() * 255.0D;
    } else if (component.equals(BLUE)) {
      result = skyColor.z() * 255.0D;
    } else if (component.equals(ALPHA)) {
      result = 255.0D;
    }

    return result;
  }
  
  @OnlyIn(Dist.CLIENT)
  private static double getStarColor(String component) {
    Minecraft minecraft = Minecraft.getInstance();
		ClientLevel clientLevel = minecraft.level;
    float partialTick = (Float) renderingManager.get("PartialTick");
    float rainLevel = 1.0F - clientLevel.getRainLevel(partialTick);
    float starColor = clientLevel.getStarBrightness(partialTick) * rainLevel;
    double result = 0.0D;

    if (component.equals(RED)) {
      result = starColor * 255.0D;
    } else if (component.equals(GREEN)) {
      result = starColor * 255.0D;
    } else if (component.equals(BLUE)) {
      result = starColor * 255.0D;
    } else if (component.equals(ALPHA)) {
      result = starColor * 255.0D;
    }

    return result;
  }
  
  @OnlyIn(Dist.CLIENT)
  private static double getSunlightColor(String component) {
    Minecraft minecraft = Minecraft.getInstance();
		ClientLevel clientLevel = minecraft.level;
    float partialTick = (Float) renderingManager.get("PartialTick");
    float[] sunlightColor = clientLevel.effects().getSunriseColor(clientLevel.getTimeOfDay(partialTick), partialTick);
    double result = 0.0D;

    if (sunlightColor != null) {
      if (component.equals(RED)) {
        result = sunlightColor[0] * 255.0D;
      } else if (component.equals(GREEN)) {
        result = sunlightColor[1] * 255.0D;
      } else if(component.equals(BLUE)) {
        result = sunlightColor[2] * 255.0D;
      } else if(component.equals(ALPHA)) {
        result = sunlightColor[3] * 255.0D;
      }
    }

    return result;
  }

  @OnlyIn(Dist.CLIENT)
  private static double getCloudHeight() {
    Minecraft minecraft = Minecraft.getInstance();
    double result = minecraft.level.effects().getCloudHeight();
    if (Double.isNaN(result)) {
      result = 0.0D;
    }
    return result;
  }

  @OnlyIn(Dist.CLIENT)
	@SubscribeEvent
	public static void onClientTick(TickEvent.ClientTickEvent event) {
		if (event.phase == TickEvent.Phase.END) {
			Minecraft minecraft = Minecraft.getInstance();
			if (minecraft.level != null && !minecraft.isPaused()) {
				ticks++;
			}
		}
  }

  <#assign dependenciesCode><#compress>
	  <@procedureDependenciesCode dependencies, {
    "dimension": "minecraft.getCameraEntity().level.dimension()",
    "entity": "minecraft.getCameraEntity()",
	  "x": "minecraft.getCameraEntity().getX()",
    "y": "minecraft.getCameraEntity().getY()",
    "z": "minecraft.getCameraEntity().getZ()",
    "world": "minecraft.getCameraEntity().level",
    "event": "event"
	  }/>
  </#compress></#assign>
  
  <#-- Render Fog #-->
  @OnlyIn(Dist.CLIENT)
	@SubscribeEvent
  public static void onRenderingFog(ViewportEvent.RenderFog event) {
    Minecraft minecraft = Minecraft.getInstance();
    eventType = RENDER_FOG;
    renderingManager.put("RenderFog", event);
    renderingManager.put("Camera", minecraft.gameRenderer.getMainCamera());
    renderingManager.put("PartialTick", minecraft.getPartialTick());
    event.setCanceled(true);
    execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
	}

  <#-- Compute Fog Color #-->
  @OnlyIn(Dist.CLIENT)
	@SubscribeEvent
  public static void onComputingFogColor(ViewportEvent.ComputeFogColor event) {
    Minecraft minecraft = Minecraft.getInstance();
    eventType = COMPUTE_FOG_COLOR;
    renderingManager.put("ComputeFogColor", event);
    renderingManager.put("Camera", minecraft.gameRenderer.getMainCamera());
    renderingManager.put("PartialTick", minecraft.getPartialTick());
    execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
	}

	@OnlyIn(Dist.CLIENT)
	@SubscribeEvent
  public static void onRenderingLevel(RenderLevelStageEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
    <#-- Render Sky #-->
    if (event.getStage() == RenderLevelStageEvent.Stage.AFTER_SKY) {
      eventType = RENDER_SKY;
      renderingManager.put("Camera", event.getCamera());
      renderingManager.put("PoseStack", event.getPoseStack());
      renderingManager.put("Matrix4f", event.getProjectionMatrix());
      renderingManager.put("PartialTick", event.getPartialTick());
      renderingManager.put("DefaultCloudStatus", minecraft.options.getCloudsType());
      minecraft.options.cloudStatus().set(CloudStatus.OFF);
      RenderSystem.clear(16640, Minecraft.ON_OSX);
      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
    }
    <#-- Render Clouds #-->
    if (event.getStage() == RenderLevelStageEvent.Stage.AFTER_WEATHER) {
			eventType = RENDER_CLOUDS;
			renderingManager.put("Camera", event.getCamera());
			renderingManager.put("PoseStack", event.getPoseStack());
			renderingManager.put("Matrix4f", event.getProjectionMatrix());
			renderingManager.put("PartialTick", event.getPartialTick());
			Minecraft.getInstance().options.cloudStatus().set((CloudStatus) renderingManager.get("DefaultCloudStatus"));
			execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
		}
	}
