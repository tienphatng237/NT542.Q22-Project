<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="xml" indent="yes"/>

  <!-- Identity transform -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- Force primary OS disk to SATA /dev/sda for Windows clone compatibility -->
  <xsl:template match="/domain/devices/disk[@device='disk'][1]/target">
    <target dev="sda" bus="sata"/>
  </xsl:template>

  <!-- Remove WWN because libvirt rejects WWN on SATA disks -->
  <xsl:template match="/domain/devices/disk[@device='disk'][1]/wwn"/>

  <!-- Keep NIC model aligned with source VM profile -->
  <xsl:template match="/domain/devices/interface[@type='network'][1]/model">
    <model type="e1000e"/>
  </xsl:template>

  <!-- Force a SPICE-friendly QXL video device with enough memory for 2K+ -->
  <xsl:template match="/domain/devices/video/model">
    <model type="qxl" ram="65536" vram="65536" heads="1"/>
  </xsl:template>
</xsl:stylesheet>
