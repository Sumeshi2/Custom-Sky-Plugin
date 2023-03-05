<#include "procedures.java.ftl">
@OnlyIn(Dist.CLIENT)
@Mod.EventBusSubscriber
public class ${name}Procedure {
  <#-- EventType #-->
  private static final String NONE = "NONE";
  private static final String RENDER_FOG = "RENDER_FOG";
  private static final String COMPUTE_FOG_COLOR = "COMPUTE_FOG_COLOR";
  private static final String RENDER_SKY = "RENDER_SKY";
  private static final String RENDER_CLOUDS = "RENDER_CLOUDS";
  private static final String RENDER_WEATHER = "RENDER_WEATHER";
  private static final String SET_WEATHER_PARTICLES = "SET_WEATHER_PARTICLES";
  <#-- Render Type #-->
  private static final String RAIN = "RAIN";
  private static final String SNOW = "SNOW";
  private static final String STORM = "STORM";
  <#-- Color Component #-->
  private static final String RED = "RED";
  private static final String GREEN = "GREEN";
  private static final String BLUE = "BLUE";
  private static final String HUE = "HUE";
  private static final String SATURATION = "SATURATION";
  private static final String BRIGHTNESS = "BRIGHTNESS";
  private static final String ALPHA = "ALPHA";
  <#-- Color Model #-->
  private static final String HSBA = "HSBA";
  private static final String RGBA = "RGBA";

  private static String eventType = NONE;
  private static ViewportEvent.RenderFog fogEvent = null;
  private static ViewportEvent.ComputeFogColor fogColorEvent = null;
  private static Camera camera = null;
  private static PoseStack poseStack = null;
  private static Matrix4f projectionMatrix = null;
  private static boolean customVanillaSky = false;
  private static CloudStatus defaultCloudStatus = null;
  private static float defaultRainLevel = 0.0F;
  private static float partialTick = 0.0F;
  private static int ticks = 0;

  private static void renderVanillaElements(boolean upSkyFlag, boolean downSkyFlag, boolean starFlag, boolean sunlightFlag, boolean sunFlag, boolean moonFlag, boolean cloudFlag, boolean weatherFlag, boolean endSkyFlag) {
    Minecraft minecraft = Minecraft.getInstance();
    ClientLevel clientLevel = minecraft.level;

    if (clientLevel.effects().skyType() == DimensionSpecialEffects.SkyType.END) {
      if (eventType.equals(RENDER_SKY)) {
        if (endSkyFlag) {
          renderTextureSky(null, "minecraft", "textures/environment/end_sky.png");
        } 
      }
    } else if (clientLevel.effects().skyType() == DimensionSpecialEffects.SkyType.NORMAL) {
      if (eventType.equals(RENDER_SKY)) {
        if (upSkyFlag) {
          double skyRed = getSkyColor(RED);
          double skyGreen = getSkyColor(GREEN);
          double skyBlue = getSkyColor(BLUE);
          double skyAlpha = getSkyColor(ALPHA);

          renderSky(Direction.UP, skyRed, skyGreen, skyBlue, skyAlpha, RGBA);
        }

        if (downSkyFlag) {
          double eyeHeight = minecraft.player.getEyePosition(partialTick).y();
          double seaLevel = clientLevel.getLevelData().getHorizonHeight(clientLevel);

          if (eyeHeight < seaLevel) {
            renderSky(Direction.DOWN, 0.0D, 0.0D, 0.0D, 255.0D, RGBA);
          }
        }

        if (starFlag) {
          double starRed = getStarColor(RED);
          double starGreen = getStarColor(GREEN);
          double starBlue = getStarColor(BLUE);
          double starAlpha = getStarColor(ALPHA);

          renderStar(1500.0D, 10842.0D, starRed, starGreen, starBlue, starAlpha, RGBA);
        }

        if (sunlightFlag) {
          double sunlightRed = getSunlightColor(RED);
          double sunlightGreen = getSunlightColor(GREEN);
          double sunlightBlue = getSunlightColor(BLUE);
          double sunlightAlpha = getSunlightColor(ALPHA);

          renderSunlight(sunlightRed, sunlightGreen, sunlightBlue, sunlightAlpha, RGBA);
        }

        if (sunFlag || moonFlag) {
          double dayTime = clientLevel.getLevelData().getDayTime();
          if (sunFlag) {
            renderTexture("minecraft", "textures/environment/sun.png", -90.0D, dayTime * -0.015D, 0.0D, 30.0D, true);
          }
          if (moonFlag) {
            renderTexture("minecraft", "textures/environment/moon_phases.png", 90.0D, dayTime * 0.015D, 0.0D, 20.0D, true);
          }
        }
      }
      if (eventType.equals(RENDER_CLOUDS)) {
        if (cloudFlag) {
          double cloudHeight = getCloudHeight();
          renderClouds(cloudHeight, -1.0D, 0.0D, "minecraft", "textures/environment/clouds.png");
        }
      }
      if (eventType.equals(RENDER_WEATHER)) {
        if (weatherFlag) {
          renderWeather(RAIN, "minecraft", "textures/environment/rain.png", true, false);
          renderWeather(SNOW, "minecraft", "textures/environment/snow.png", true, false);
        }
      }
      if (eventType.equals(SET_WEATHER_PARTICLES)) {
        if (weatherFlag) {
          ParticleOptions normal = ParticleTypes.RAIN;
          ParticleOptions vapor = ParticleTypes.SMOKE;
          net.minecraft.sounds.SoundEvent sound = ForgeRegistries.SOUND_EVENTS.getValue(new ResourceLocation("weather.rain"));

          setWeatherParticles(normal, vapor, sound, true, false);
        }
      }
    }
  }

  private static void renderSky(Direction direction, double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      float[] skyColor = convertColor(color0, color1, color2, color3, colorModel);

      if (skyColor[3] > 0.0F) {
        VertexBuffer skyBuffer = new VertexBuffer();

        RenderSystem.disableTexture();
        RenderSystem.depthMask(false);
	      RenderSystem.enableBlend();
	      RenderSystem.defaultBlendFunc();
        RenderSystem.setShaderColor(skyColor[0], skyColor[1], skyColor[2], skyColor[3]);
        RenderSystem.setShader(GameRenderer::getPositionShader);

        BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
        float vertex0 = -16.0F;
		    float vertex1 = -512.0F;

		    bufferBuilder.begin(VertexFormat.Mode.TRIANGLE_FAN, DefaultVertexFormat.POSITION);
		    bufferBuilder.vertex(0.0D, (double) vertex0, 0.0D).endVertex();
		    for (int i = -180; i <= 180; i += 45) {
			    bufferBuilder.vertex((double) vertex1 * Mth.cos((float) i * ((float) Math.PI / 180F)), 0.0D, (double) (512.0F * Mth.sin((float) i * ((float) Math.PI / 180F)))).endVertex();
		    }
		    BufferBuilder.RenderedBuffer renderedBuffer = bufferBuilder.end();
        poseStack.pushPose();
        if (direction == Direction.DOWN) {
          poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			  }
        if (direction == Direction.UP) {
				  poseStack.mulPose(Vector3f.XP.rotationDegrees(180.0F));
          poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			  }
        if (direction == Direction.NORTH) {
				  poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
			  }
			  if (direction == Direction.EAST) {
          poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				  poseStack.mulPose(Vector3f.ZP.rotationDegrees(-90.0F));
			  }
			  if (direction == Direction.SOUTH) {
          poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				  poseStack.mulPose(Vector3f.ZP.rotationDegrees(-180.0F));
			  }
			  if (direction == Direction.WEST) {
				  poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				  poseStack.mulPose(Vector3f.ZP.rotationDegrees(-270.0F));
			  }
        skyBuffer.bind();
	      skyBuffer.upload(renderedBuffer);
        skyBuffer.drawWithShader(poseStack.last().pose(), projectionMatrix, RenderSystem.getShader());
        skyBuffer.close();
        poseStack.popPose();
        bufferBuilder.discard();

        RenderSystem.disableBlend();
        RenderSystem.depthMask(true);
        RenderSystem.enableTexture();
      }
    }
  }

  private static void renderTextureSky(@Nullable Direction direction, String id, String path) {
    if (eventType.equals(RENDER_SKY)) {
      Minecraft minecraft = Minecraft.getInstance();
      if (!minecraft.gui.getBossOverlay().shouldCreateWorldFog()) {
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
        bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION_TEX_COLOR);
        if (direction == null) {
          for (int i = 0; i < 6; i++) {
            poseStack.pushPose();
            if (i == 0) {
              poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			      }
            if (i == 1) {
				      poseStack.mulPose(Vector3f.XP.rotationDegrees(180.0F));
              poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			      }
			      if (i == 2) {
				      poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
			      }
			      if (i == 3) {
              poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				      poseStack.mulPose(Vector3f.ZP.rotationDegrees(-90.0F));
			      }
			      if (i == 4) {
              poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				      poseStack.mulPose(Vector3f.ZP.rotationDegrees(-180.0F));
			      }
			      if (i == 5) {
				      poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				      poseStack.mulPose(Vector3f.ZP.rotationDegrees(-270.0F));
			      }
			      Matrix4f rotationMatrix = poseStack.last().pose();
			      bufferBuilder.vertex(rotationMatrix, -100.0F, -100.0F, -100.0F).uv(uv0, uv1).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			      bufferBuilder.vertex(rotationMatrix, -100.0F, -100.0F, 100.0F).uv(uv1, uv2).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			      bufferBuilder.vertex(rotationMatrix, 100.0F, -100.0F, 100.0F).uv(uv2, uv3).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			      bufferBuilder.vertex(rotationMatrix, 100.0F, -100.0F, -100.0F).uv(uv3, uv0).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
            poseStack.popPose();
          }
        } else {
          poseStack.pushPose();
          if (direction == Direction.DOWN) {
            poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			    }
          if (direction == Direction.UP) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(180.0F));
            poseStack.mulPose(Vector3f.YP.rotationDegrees(180.0F));
			    }
          if (direction == Direction.NORTH) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
			    }
			    if (direction == Direction.EAST) {
            poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-90.0F));
			    }
			    if (direction == Direction.SOUTH) {
            poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-180.0F));
			    }
			    if (direction == Direction.WEST) {
				    poseStack.mulPose(Vector3f.XP.rotationDegrees(90.0F));
				    poseStack.mulPose(Vector3f.ZP.rotationDegrees(-270.0F));
			    }
          Matrix4f rotationMatrix = poseStack.last().pose();
			    bufferBuilder.vertex(rotationMatrix, -100.0F, -100.0F, -100.0F).uv(uv0, uv1).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(rotationMatrix, -100.0F, -100.0F, 100.0F).uv(uv1, uv2).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(rotationMatrix, 100.0F, -100.0F, 100.0F).uv(uv2, uv3).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
			    bufferBuilder.vertex(rotationMatrix, 100.0F, -100.0F, -100.0F).uv(uv3, uv0).color(skyRed, skyGreen, skyBlue, skyAlpha).endVertex();
          poseStack.popPose();
        }
		    BufferUploader.drawWithShader(bufferBuilder.end());
        bufferBuilder.discard();

		    RenderSystem.disableBlend();
        RenderSystem.depthMask(true);
      }
    }
  }
  
	private static void renderClouds(double height, double vx0, double vz0, String id, String path) {
    if (eventType.equals(RENDER_CLOUDS)) {
      Minecraft minecraft = Minecraft.getInstance();
      ClientLevel clientLevel = minecraft.level;
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
        Vec3 cameraPos = camera.getPosition();
				double cameraX = cameraPos.x();
				double cameraY = cameraPos.y();
				double cameraZ = cameraPos.z();
				VertexBuffer cloudBuffer = new VertexBuffer();

        RenderSystem.enableTexture();
				RenderSystem.depthMask(true);
				RenderSystem.enableBlend();
				RenderSystem.enableDepthTest();
				RenderSystem.blendFuncSeparate(GlStateManager.SourceFactor.SRC_ALPHA, GlStateManager.DestFactor.ONE_MINUS_SRC_ALPHA, GlStateManager.SourceFactor.ONE, GlStateManager.DestFactor.ONE_MINUS_SRC_ALPHA);
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
          cloudBuffer.drawWithShader(poseStack.last().pose(), projectionMatrix, RenderSystem.getShader());
          RenderSystem.colorMask(true, true, true, true);
          cloudBuffer.drawWithShader(poseStack.last().pose(), projectionMatrix, RenderSystem.getShader());
        } else {
          RenderSystem.colorMask(true, true, true, true);
          cloudBuffer.drawWithShader(poseStack.last().pose(), projectionMatrix, RenderSystem.getShader());
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

  private static void renderWeather(String renderType, String id, String path, boolean biomeEffect, boolean immutability) {
		if (eventType.equals(RENDER_WEATHER)) {
			Minecraft minecraft = Minecraft.getInstance();
			ClientLevel clientLevel = minecraft.level;
      float rainLevel = clientLevel.getRainLevel(partialTick);
      boolean flag0 = true;
      if (!immutability && rainLevel <= 0) {
        flag0 = false;
      }

			if (flag0) {
				Level level = (Level) clientLevel;
				LightTexture lightTexture = new LightTexture(minecraft.gameRenderer, minecraft);
				lightTexture.turnOnLightLayer();
				Vec3 cameraPos = camera.getPosition();
				double camX = cameraPos.x();
				double camY = cameraPos.y();
				double camZ = cameraPos.z();
				int posX = Mth.floor(camX);
				int posY = Mth.floor(camY);
				int posZ = Mth.floor(camZ);
				float[] rainSizeX = new float[1024];
				float[] rainSizeZ = new float[1024];
				int amount = 5;
				int minX = 0;
				int minZ = 0;
				int maxX = 0;
				int maxZ = 0;
				float factor = ticks + partialTick;
				BlockPos.MutableBlockPos mutableBlockPos = new BlockPos.MutableBlockPos();

				for (int i = 0; i < 32; i++) {
					for (int j = 0; j < 32; j++) {
						float float0 = i - 16;
						float float1 = j - 16;
						float sqrt = Mth.sqrt(float0 * float0 + float1 * float1);
						rainSizeX[i << 5 | j] = float0 / sqrt;
						rainSizeZ[i << 5 | j] = -float1 / sqrt;
					}
				}
				if (Minecraft.useFancyGraphics()) {
					amount = 10;
				}
				
        Tesselator tesselator = Tesselator.getInstance();
				BufferBuilder bufferBuilder = tesselator.getBuilder();
				RenderSystem.enableTexture();
				RenderSystem.depthMask(false);
				RenderSystem.enableDepthTest();
				RenderSystem.depthMask(Minecraft.useShaderTransparency());
				RenderSystem.enableBlend();
				RenderSystem.defaultBlendFunc();
				RenderSystem.setShader(GameRenderer::getParticleShader);
        RenderSystem.setShaderColor(1.0F, 1.0F, 1.0F, 1.0F);
        RenderSystem.setShaderTexture(0, new ResourceLocation(id, path));
				RenderSystem.disableCull();
				
				minX = posX - amount;
				minZ = posZ - amount;
				maxX = posX + amount;
				maxZ = posZ + amount;
				bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.PARTICLE);
				for (int i = minX; i <= maxX; i++) {
					for (int j = minZ; j <= maxZ; j++) {
						mutableBlockPos.set(i, camY, j);
						Biome biome = level.getBiome(mutableBlockPos).value();
            int index = i - posX + 16 + (j - posZ + 16) * 32;
						double sizeX = rainSizeX[index] * 0.5D;
						double sizeZ = rainSizeZ[index] * 0.5D;
						int height = level.getHeight(Heightmap.Types.MOTION_BLOCKING, i, j);
						int minY = posY - amount;
						int maxY = posY + amount;

						if (minY < height) {
							minY = height;
						}
						if (maxY < height) {
							maxY = height;
						}
						int blockPosY = height;
						if (height < posY) {
							blockPosY = posY;
						}
						if (minY != maxY) {
							RandomSource randomSource = RandomSource.create((long) ((i * i * 3121 + i * 45238971) ^ (j * j * 418711 + j * 13761)));
              float speedFactor = 1.0F;
              float weatherAlpha = 1.0F;
              boolean flag1 = false;

							mutableBlockPos.set(i, minY, j);
              if (biomeEffect) {
								if (biome.getPrecipitation() == Biome.Precipitation.NONE) {
									flag1 = false;
								} else {
									boolean rainnable = biome.warmEnoughToRain(mutableBlockPos);
									if (renderType.equals(RAIN) && rainnable) {
										flag1 = true;
									} else if (renderType.equals(SNOW) && !rainnable) {
										flag1 = true;
									} else {
										flag1 = false;
									}
								}
							} else {
								if (immutability) {
									flag1 = true;
								}
							}
              if (renderType.equals(STORM)) {
                flag1 = true;
                speedFactor = 10.0F;
              }
							if (!immutability && flag1) {
								double dx = i + 0.5D - camX;
								double dz = j + 0.5D - camZ;
								float distance = (float) Math.sqrt(dx * dx + dz * dz) / amount;
								weatherAlpha = ((1.0F - distance * distance) * 0.5F + 0.5F) * rainLevel;
							}

							if (renderType.equals(RAIN) && flag1) {
								int int0 = ticks + i * i * 3121 + i * 45238971 + j * j * 418711 + j * 13761 & 31;
							  float float0 = -(int0 + partialTick) / 32.0F * (3.0F + randomSource.nextFloat());
							  mutableBlockPos.set(i, blockPosY, j);
							  int int1 = LevelRenderer.getLightColor(level, mutableBlockPos);

							  bufferBuilder.vertex(i - camX - sizeX + 0.5D, maxY - camY, j - camZ - sizeZ + 0.5D).uv(0.0F, minY * 0.25F + float0).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(int1).endVertex();
							  bufferBuilder.vertex(i - camX + sizeX + 0.5D, maxY - camY, j - camZ + sizeZ + 0.5D).uv(1.0F, minY * 0.25F + float0).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(int1).endVertex();
							  bufferBuilder.vertex(i - camX + sizeX + 0.5D, minY - camY, j - camZ + sizeZ + 0.5D).uv(1.0F, maxY * 0.25F + float0).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(int1).endVertex();
							  bufferBuilder.vertex(i - camX - sizeX + 0.5D, minY - camY, j - camZ - sizeZ + 0.5D).uv(0.0F, maxY * 0.25F + float0).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(int1).endVertex();
							} else if ((renderType.equals(SNOW) || renderType.equals(STORM)) && flag1) {
							  float float0 = ((ticks & 511) + partialTick) / -512.0F;
							  float float1 = (float) (randomSource.nextDouble() + factor * speedFactor * randomSource.nextGaussian() * 0.01D);
							  float float2 = (float) (randomSource.nextDouble() + factor * speedFactor * randomSource.nextGaussian() * 0.001D);
							  mutableBlockPos.set(i, blockPosY, j);
							  int int0 = LevelRenderer.getLightColor(level, mutableBlockPos);
							  int int1 = int0 & '\uffff';
							  int int2 = int0 >> 16 & '\uffff';
							  int u = (int1 * 3 + 240) / 4;
							  int v = (int2 * 3 + 240) / 4;

							  bufferBuilder.vertex(i - camX - sizeX + 0.5D, maxY - camY, j - camZ - sizeZ + 0.5D).uv(0.0F + float1, minY * 0.25F + float0 + float2).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(u, v).endVertex();
							  bufferBuilder.vertex(i - camX + sizeX + 0.5D, maxY - camY, j - camZ + sizeZ + 0.5D).uv(1.0F + float1, minY * 0.25F + float0 + float2).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(u, v).endVertex();
							  bufferBuilder.vertex(i - camX + sizeX + 0.5D, minY - camY, j - camZ + sizeZ + 0.5D).uv(1.0F + float1, maxY * 0.25F + float0 + float2).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(u, v).endVertex();
							  bufferBuilder.vertex(i - camX - sizeX + 0.5D, minY - camY, j - camZ - sizeZ + 0.5D).uv(0.0F + float1, maxY * 0.25F + float0 + float2).color(1.0F, 1.0F, 1.0F, weatherAlpha).uv2(u, v).endVertex();
              }
						}
					}
				}

				tesselator.end();
				bufferBuilder.discard();
				lightTexture.turnOffLightLayer();
				RenderSystem.enableCull();
				RenderSystem.disableBlend();
				RenderSystem.depthMask(true);
				RenderSystem.disableTexture();
			}
		}
	}

  private static void setWeatherParticles(ParticleOptions normal, ParticleOptions vapor, net.minecraft.sounds.SoundEvent sound, boolean biomeEffect, boolean immutability) {
    if (eventType.equals(SET_WEATHER_PARTICLES)) {
      Minecraft minecraft = Minecraft.getInstance();
			ClientLevel clientLevel = minecraft.level;
      float rainLevel = clientLevel.getRainLevel(partialTick);
      boolean flag0 = true;
      if (!immutability && rainLevel <= 0) {
        flag0 = false;
      }

      if (flag0) {
        RandomSource randomSource = RandomSource.create((long) ticks * 312987231L);
        LevelReader levelReader = clientLevel;
        BlockPos blockPos0 = new BlockPos(camera.getPosition());
        BlockPos blockPos1 = null;
        float factor = 0.0F;
        int particleStatus = 0;
        int amount = 0;

        if (minecraft.options.particles().get() == ParticleStatus.DECREASED) {
          particleStatus = 2;
        } else {
          particleStatus = 1;
        }
        if (immutability) {
          factor = 1.0F;
        } else {
          factor = rainLevel * rainLevel;
        }

        amount = (int) (100.0F * factor) / particleStatus;

        for (int i = 0; i < amount; i++) {
          int random0X = randomSource.nextInt(21) - 10;
          int random0Z = randomSource.nextInt(21) - 10;
          BlockPos blockPos2 = levelReader.getHeightmapPos(Heightmap.Types.MOTION_BLOCKING, blockPos0.offset(random0X, 0, random0Z));
          Biome biome = levelReader.getBiome(blockPos2).value();
          int pos0Y = blockPos0.getY();
          int pos2Y = blockPos2.getY();
          if (pos2Y > levelReader.getMinBuildHeight() && pos2Y <= pos0Y + 10 && pos2Y >= pos0Y - 10) {
            boolean flag1 = false;

            if (biomeEffect) {
              if (biome.getPrecipitation() == Biome.Precipitation.RAIN && biome.warmEnoughToRain(blockPos2)) {
                flag1 = true;
              } else {
                flag1 = false;
              }
            } else {
              flag1 = true;
            }

            if (flag1) {
              blockPos1 = blockPos2.below();
              if (minecraft.options.particles().get() == ParticleStatus.MINIMAL) {
                break;
              }

              double random1X = randomSource.nextDouble();
              double random1Z = randomSource.nextDouble();
              BlockState blockState = levelReader.getBlockState(blockPos1);
              FluidState fluidState = levelReader.getFluidState(blockPos1);
              VoxelShape voxelShape = blockState.getCollisionShape(levelReader, blockPos1);
              double double0 = voxelShape.max(Direction.Axis.Y, random1X, random1Z);
              double double1 = fluidState.getHeight(levelReader, blockPos1);
              double double2 = Math.max(double0, double1);
              ParticleOptions particle = normal;
              if (fluidState.is(FluidTags.LAVA) || blockState.is(Blocks.MAGMA_BLOCK) || CampfireBlock.isLitCampfire(blockState)) {
                particle = vapor;
              }

              clientLevel.addParticle(particle, blockPos1.getX() + random1X, blockPos1.getY() + double2, blockPos1.getZ() + random1Z, 0.0D, 0.0D, 0.0D);
            }
          }
        }

        if (blockPos1 != null && randomSource.nextInt(3) == 0) {
          float height = levelReader.getHeightmapPos(Heightmap.Types.MOTION_BLOCKING, blockPos0).getY();

          if (blockPos1.getY() > blockPos0.getY() + 1 && height > blockPos0.getY()) {
            if (sound == SoundEvents.WEATHER_RAIN) {
              clientLevel.playLocalSound(blockPos1, SoundEvents.WEATHER_RAIN_ABOVE, SoundSource.WEATHER, 0.1F, 0.5F, false);
            } else {
              clientLevel.playLocalSound(blockPos1, sound, SoundSource.WEATHER, 0.1F, 0.5F, false);
            }
          } else {
             clientLevel.playLocalSound(blockPos1, sound, SoundSource.WEATHER, 0.2F, 1.0F, false);
          }
        }
      }
    }
  }

  private static void renderFog(FogShape shape, double start, double end, double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_FOG)) {
      fogEvent.setFogShape(shape);
      fogEvent.setNearPlaneDistance((float) start);
      fogEvent.setFarPlaneDistance((float) end);
    }
    if (eventType.equals(COMPUTE_FOG_COLOR) || eventType.equals(RENDER_SKY)) {
      float[] fogColor = convertColor(color0, color1, color2, color3, colorModel);

      if (eventType.equals(COMPUTE_FOG_COLOR)) {
        fogColorEvent.setRed(fogColor[0]);
        fogColorEvent.setGreen(fogColor[1]);
        fogColorEvent.setBlue(fogColor[2]);
      } else if (eventType.equals(RENDER_SKY)) {
        RenderSystem.setShaderFogColor(fogColor[0], fogColor[1], fogColor[2], fogColor[3]);
      }
    }
  }

  private static void renderSunlight(double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      float[] sunlightColor = convertColor(color0, color1, color2, color3, colorModel);

      if (sunlightColor[3] > 0.0F) {
        Minecraft minecraft = Minecraft.getInstance();
		    ClientLevel clientLevel = minecraft.level;
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
			  Matrix4f rotationMatrix = poseStack.last().pose();
			  bufferBuilder.begin(VertexFormat.Mode.TRIANGLE_FAN, DefaultVertexFormat.POSITION_COLOR);
			  bufferBuilder.vertex(rotationMatrix, 0.0F, 100.0F, 0.0F).color(sunlightRed, sunlightGreen, sunlightBlue, sunlightAlpha).endVertex();
			  for (int i = 0; i <= 16; ++i) {
			    float radian = (float) i * ((float) Math.PI * 2F) / 16.0F;
			    float sin = Mth.sin(radian);
			    float cos = Mth.cos(radian);
			    bufferBuilder.vertex(rotationMatrix, sin * 120.0F, cos * 120.0F, -cos * 40.0F * sunlightAlpha).color(sunlightRed, sunlightGreen, sunlightBlue, 0.0F).endVertex();
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

  private static void renderStar(double amount, double seed, double color0, double color1, double color2, double color3, String colorModel) {
    if (eventType.equals(RENDER_SKY)) {
      int starAmount = (int) amount;
      float[] starColor = convertColor(color0, color1, color2, color3, colorModel);

      if (starAmount > 0 && starColor[3] > 0.0F) {
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
			  starBuffer.drawWithShader(poseStack.last().pose(), projectionMatrix, GameRenderer.getPositionShader());
        starBuffer.close();
			  poseStack.popPose();
        bufferBuilder.discard();

			  RenderSystem.disableBlend();
			  RenderSystem.depthMask(true);
			  RenderSystem.enableTexture();
      }
    }
  }
  
  private static void renderTexture(String id, String path, double yaw, double pitch, double roll, double size, boolean weatherEffect) {
    if (eventType.equals(RENDER_SKY)) {
      Minecraft minecraft = Minecraft.getInstance();
		  ClientLevel clientLevel = minecraft.level;
      float pos = (float) size;
      float uv0 = 1.0F;
      float uv1 = 1.0F;
      float uv2 = 0.0F;
      float uv3 = 0.0F;
      float alpha = 1.0F;
      if (weatherEffect) {
        alpha -= clientLevel.getRainLevel(partialTick);
      }
      boolean isVanillaSun = false;
      boolean isVanillaMoon = false;

      if (id.equals("minecraft") && path.equals("textures/environment/sun.png")) {
        isVanillaSun = true;
      } else if (id.equals("minecraft") && path.equals("textures/environment/moon_phases.png")) {
        int phase = clientLevel.getMoonPhase();
        int int0 = phase % 4;
        int int1 = phase / 4 % 2;
        uv0 = (float) (int0 + 0) / 4.0F;
        uv1 = (float) (int1 + 0) / 2.0F;
        uv2 = (float) (int0 + 1) / 4.0F;
        uv3 = (float) (int1 + 1) / 2.0F;
        isVanillaMoon = true;
      }

      RenderSystem.enableBlend();
	    RenderSystem.defaultBlendFunc();
      if (isVanillaSun || isVanillaMoon) {
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
      Matrix4f rotationMatrix = poseStack.last().pose();
      BufferBuilder bufferBuilder = Tesselator.getInstance().getBuilder();
      bufferBuilder.begin(VertexFormat.Mode.QUADS, DefaultVertexFormat.POSITION_TEX);
	    bufferBuilder.vertex(rotationMatrix, -pos, 100.0F, -pos).uv(uv2, uv3).endVertex();
      bufferBuilder.vertex(rotationMatrix, pos, 100.0F, -pos).uv(uv0, uv3).endVertex();
      bufferBuilder.vertex(rotationMatrix, pos, 100.0F, pos).uv(uv0, uv1).endVertex();
      bufferBuilder.vertex(rotationMatrix, -pos, 100.0F, pos).uv(uv2, uv1).endVertex();
      poseStack.popPose();
	    BufferUploader.drawWithShader(bufferBuilder.end());
      bufferBuilder.discard();

	    RenderSystem.disableTexture();
	    RenderSystem.disableBlend();
    }
  }

  private static boolean isRenderable() {
    String modid = Minecraft.getInstance().level.dimensionTypeId().location().getNamespace();
    boolean flag = false;

    if (customVanillaSky) {
      if (modid.equals("minecraft")) {
        flag = true;
      }
    }
    if (modid.equals("${modid}")) {
      flag = true;
    }

    return flag;
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

  private static double getCloudHeight() {
    double result = 0.0D;
    if (!eventType.equals(NONE)) {
      result = Minecraft.getInstance().level.effects().getCloudHeight();
      if (Double.isNaN(result)) {
        result = 0.0D;
      }
    }
    return result;
  }

  private static double getFogEndDistance() {
    double result = 0.0D;
    if (!eventType.equals(NONE)) {
      result = RenderSystem.getShaderFogEnd();
    }
    return result;
  }

  private static double getFogStartDistance() {
    double result = 0.0D;
    if (!eventType.equals(NONE)) {
      result = RenderSystem.getShaderFogStart();
    }
    return result;
  }

  private static double getFogColor(String component) {
    double result = 0.0D;

    if (!eventType.equals(NONE)) {
      FogRenderer.levelFogColor();
      float[] fogColor = RenderSystem.getShaderFogColor();

      if (component.equals(RED) || component.equals(GREEN) || component.equals(BLUE)) {
        if (component.equals(RED)) {
          result = fogColor[0] * 255.0D;
        } else if (component.equals(GREEN)) {
          result = fogColor[1] * 255.0D;
        } else if (component.equals(BLUE)) {
          result = fogColor[2] * 255.0D;
        }
      } else if (component.equals(HUE) || component.equals(SATURATION) || component.equals(BRIGHTNESS)) {
        float[] resultColor = RGBAToHSBA(fogColor[0], fogColor[1], fogColor[2], fogColor[3]);

        if (component.equals(HUE)) {
          result = resultColor[0];
        } else if (component.equals(SATURATION)) {
          result = resultColor[1];
        } else if (component.equals(BRIGHTNESS)) {
          result = resultColor[2];
        }
      } else if (component.equals(ALPHA)) {
        result = 100.0D;
      }
    }

    return result;
  }
  
  private static double getSkyColor(String component) {
    double result = 0.0D;

    if (!eventType.equals(NONE)) {
      ClientLevel clientLevel = Minecraft.getInstance().level;
      Vec3 skyColor = clientLevel.getSkyColor(camera.getPosition(), partialTick);

      if (component.equals(RED) || component.equals(GREEN) || component.equals(BLUE)) {
        if (component.equals(RED)) {
          result = skyColor.x() * 255.0D;
        } else if (component.equals(GREEN)) {
          result = skyColor.y() * 255.0D;
        } else if (component.equals(BLUE)) {
          result = skyColor.z() * 255.0D;
        }
      } else if (component.equals(HUE) || component.equals(SATURATION) || component.equals(BRIGHTNESS)) {
        float[] resultColor = RGBAToHSBA(skyColor.x(), skyColor.y(), skyColor.z(), 1.0D);

        if (component.equals(HUE)) {
          result = resultColor[0];
        } else if (component.equals(SATURATION)) {
          result = resultColor[1];
        } else if (component.equals(BRIGHTNESS)) {
          result = resultColor[2];
        }
      } else if (component.equals(ALPHA)) {
        result = 100.0D;
      }
    }

    return result;
  }
  
  private static double getStarColor(String component) {
    double result = 0.0D;

    if (!eventType.equals(NONE)) {
      ClientLevel clientLevel = Minecraft.getInstance().level;
      float rainLevel = 1.0F - clientLevel.getRainLevel(partialTick);
      float starColor = clientLevel.getStarBrightness(partialTick) * rainLevel;

      if (component.equals(RED) || component.equals(GREEN) || component.equals(BLUE)) {
        if (component.equals(RED)) {
          result = starColor * 255.0D;
        } else if (component.equals(GREEN)) {
          result = starColor * 255.0D;
        } else if (component.equals(BLUE)) {
          result = starColor * 255.0D;
        }
      } else if (component.equals(HUE) || component.equals(SATURATION) || component.equals(BRIGHTNESS)) {
        float[] resultColor = RGBAToHSBA(starColor, starColor, starColor, starColor);

        if (component.equals(HUE)) {
          result = resultColor[0];
        } else if (component.equals(SATURATION)) {
          result = resultColor[1];
        } else if (component.equals(BRIGHTNESS)) {
          result = resultColor[2];
        }
      } else if (component.equals(ALPHA)) {
        result = starColor * 100.0D;
      }
    }

    return result;
  }
  
  private static double getSunlightColor(String component) {
    double result = 0.0D;

    if (!eventType.equals(NONE)) {
      ClientLevel clientLevel = Minecraft.getInstance().level;
      float[] sunlightColor = clientLevel.effects().getSunriseColor(clientLevel.getTimeOfDay(partialTick), partialTick);

      if (sunlightColor != null) {
        if (component.equals(RED) || component.equals(GREEN) || component.equals(BLUE)) {
          if (component.equals(RED)) {
            result = sunlightColor[0] * 255.0D;
          } else if (component.equals(GREEN)) {
            result = sunlightColor[1] * 255.0D;
          } else if (component.equals(BLUE)) {
            result = sunlightColor[2] * 255.0D;
          }
        } else if (component.equals(HUE) || component.equals(SATURATION) || component.equals(BRIGHTNESS)) {
          float[] resultColor = RGBAToHSBA(sunlightColor[0], sunlightColor[1], sunlightColor[2], sunlightColor[3]);

          if (component.equals(HUE)) {
            result = resultColor[0];
          } else if (component.equals(SATURATION)) {
            result = resultColor[1];
          } else if (component.equals(BRIGHTNESS)) {
            result = resultColor[2];
          }
        } else if (component.equals(ALPHA)) {
          result = sunlightColor[3] * 100.0D;
        } 
      }
    }

    return result;
  }

  private static float[] convertColor(double color0, double color1, double color2, double color3, String colorModel) {
    float[] result = new float[4];

    if (colorModel.equals(RGBA)) {
      if (color0 < 0.0D) {
        color0 = 0.0D;
      }
      if (color0 > 255.0D) {
        color0 = 255.0D;
      }
      if (color1 < 0.0D) {
        color1 = 0.0D;
      }
      if (color1 > 255.0D) {
        color1 = 255.0D;
      }
      if (color2 < 0.0D) {
        color2 = 0.0D;
      }
      if (color2 > 255.0D) {
        color2 = 255.0D;
      }
      if (color3 < 0.0D) {
        color3 = 0.0D;
      }
      if (color3 > 100.0D) {
        color3 = 100.0D;
      }

      result[0] = ((float) color0) / 255.0F;
      result[1] = ((float) color1) / 255.0F;
      result[2] = ((float) color2) / 255.0F;
      result[3] = ((float) color3) / 100.0F;
    }
    if (colorModel.equals(HSBA)) {
      float[] color = HSBAToRGBA(color0, color1, color2, color3);
      for (int i = 0; i < 4; i++) {
        result[i] = color[i];
      }
    }

    return result;
  }

  private static float[] HSBAToRGBA(double hue, double saturation, double brightness, double alpha) {
    float float0 = 0.0F;
    float float1 = 0.0F;
    float float2 = 0.0F;
    float[] color = new float[3];
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
      color[0] = float0;
      color[1] = float1;
      color[2] = 0.0F;
    } else if (60.0D <= hue && hue < 120.0D) {
      color[0] = float1;
      color[1] = float0;
      color[2] = 0.0F;
    } else if (120.0D <= hue && hue < 180.0D) {
      color[0] = 0.0F;
      color[1] = float0;
      color[2] = float1;
    } else if(180.0D <= hue && hue < 240.0D) {
      color[0] = 0.0F;
      color[1] = float1;
      color[2] = float0;
    } else if(240.0D <= hue && hue < 300.0D) {
      color[0] = float1;
      color[1] = 0.0F;
      color[2] = float0;
    } else if(300.0D <= hue && hue < 360.0D) {
      color[0] = float0;
      color[1] = 0.0F;
      color[2] = float1;
    }

    result[0] = (color[0] + float2);
    result[1] = (color[1] + float2);
    result[2] = (color[2] + float2);
    result[3] = ((float) alpha);

    return result;
  }

  private static float[] RGBAToHSBA(double red, double green, double blue, double alpha) {
    float max = (float) (Math.max(Math.max(red, green), blue));
    float min = (float) (Math.min(Math.min(red, green), blue));
    float delta = max - min;
    float[] result = new float[4];

    if (delta == 0.0F) {
      result[0] = 0.0F;
    }
    if (max == red) {
      result[0] = 60.0F * (((float) (green - blue) / delta) % 6.0F);
    }
    if (max == green) {
      result[0] = 60.0F * (((float) (blue - red) / delta) + 2.0F);
    }
    if (max == blue) {
      result[0] = 60.0F * (((float) (red - green) / delta) + 4.0F);
    }
    if (max == 0.0F) {
      result[1] = 0.0F;
    }
    if (max != 0.0F) {
      result[1] = (delta / max) * 100.0F;
    }
    result[2] = max * 100.0F;
    result[3] = (float) alpha * 100.0F;

    return result;
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
	@SubscribeEvent
  public static void onRenderFog(ViewportEvent.RenderFog event) {
    Minecraft minecraft = Minecraft.getInstance();

    if (isRenderable()) {
      eventType = RENDER_FOG;
      fogEvent = event;
      camera = minecraft.gameRenderer.getMainCamera();
      partialTick = minecraft.getFrameTime();

      event.setCanceled(true);
      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
      eventType = NONE;
    } else {
      eventType = NONE;
      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
    }
	}

  <#-- Compute Fog Color #-->
	@SubscribeEvent
  public static void onComputeFogColor(ViewportEvent.ComputeFogColor event) {
    Minecraft minecraft = Minecraft.getInstance();

    if (isRenderable()) {
      eventType = COMPUTE_FOG_COLOR;
      fogColorEvent = event;
      camera = minecraft.gameRenderer.getMainCamera();
      partialTick = minecraft.getFrameTime();

      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
      eventType = NONE;
    } else {
      eventType = NONE;
      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
    }
	}

	@SubscribeEvent
  public static void onRenderLevel(RenderLevelStageEvent event) {
    Minecraft minecraft = Minecraft.getInstance();
    RenderLevelStageEvent.Stage stage = event.getStage();

    if (isRenderable()) {
      if (stage == RenderLevelStageEvent.Stage.AFTER_SKY) {
        <#-- Render Sky #-->
        eventType = RENDER_SKY;
        camera = event.getCamera();
        poseStack = event.getPoseStack();
        projectionMatrix = event.getProjectionMatrix();
        defaultCloudStatus = minecraft.options.getCloudsType();
        partialTick = event.getPartialTick();

        RenderSystem.clear(16640, Minecraft.ON_OSX);
        execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
        eventType = NONE;
      } else if (stage == RenderLevelStageEvent.Stage.AFTER_PARTICLES) {
        <#-- Render Clouds #-->
        eventType = RENDER_CLOUDS;
			  camera = event.getCamera();
        poseStack = event.getPoseStack();
        projectionMatrix = event.getProjectionMatrix();
        partialTick = event.getPartialTick();

        defaultCloudStatus = minecraft.options.getCloudsType();
        defaultRainLevel = minecraft.level.getRainLevel(partialTick);
        execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
        minecraft.options.cloudStatus().set(CloudStatus.OFF);
        minecraft.level.setRainLevel(0.0F);
				eventType = NONE;
      }  else if (stage == RenderLevelStageEvent.Stage.AFTER_WEATHER) {
        <#-- Render Weather #-->
        eventType = RENDER_WEATHER;
				camera = event.getCamera();
				poseStack = event.getPoseStack();
				projectionMatrix = event.getProjectionMatrix();
				partialTick = event.getPartialTick();

				minecraft.options.cloudStatus().set(defaultCloudStatus);
        minecraft.level.setRainLevel(defaultRainLevel);
				execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
				eventType = NONE;
		  }
    } else {
      eventType = NONE;
      execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
    }
	}

  @SubscribeEvent
	public static void onClientTick(TickEvent.ClientTickEvent event) {
		Minecraft minecraft = Minecraft.getInstance();
		ClientLevel clientLevel = minecraft.level;
		
		if (clientLevel != null && !minecraft.isPaused()) {
      TickEvent.Phase phase = event.phase;

			if (phase == TickEvent.Phase.START) {
        if (isRenderable()) {
          <#-- Set Weather Particles #-->
          eventType = SET_WEATHER_PARTICLES;
          camera = minecraft.gameRenderer.getMainCamera();
          partialTick = minecraft.getFrameTime();
          defaultRainLevel = clientLevel.getRainLevel(partialTick);

          execute(event<#if dependenciesCode?has_content>,</#if>${dependenciesCode});
				  clientLevel.setRainLevel(0.0F);
          eventType = NONE;
        }
			} else if (phase == TickEvent.Phase.END) {
				ticks++;
        if (isRenderable()) {
				  clientLevel.setRainLevel(defaultRainLevel);
        }
			}
		}
  }